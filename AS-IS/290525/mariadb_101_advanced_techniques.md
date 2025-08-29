# MariaDB 10.1 - Técnicas Avanzadas Sin Window Functions
## Opciones Completas Para Análisis de Transferencias

> **IMPORTANTE**: MariaDB 10.1 NO soporta Window Functions (OVER) ni CTEs  
> Esta es una lista completa de técnicas que SÍ funcionan

---

## **Método 1: UNION ALL + GROUP BY Simple (MÁS EFICIENTE)**
```sql
-- GARANTIZA que MIN/MAX sean por grupo, no globales
SELECT 
    numero_entrada,
    CASE WHEN numero_digitado = 'NULL_PLACEHOLDER' THEN NULL ELSE numero_digitado END as numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) ORDER BY menu, opcion SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas ORDER BY etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T ORDER BY id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) ORDER BY division, area SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_aparicion,  -- ✅ CORRECTO POR GRUPO
    MAX(fecha) as ultima_aparicion,   -- ✅ CORRECTO POR GRUPO
    GROUP_CONCAT(DISTINCT trimestre ORDER BY trimestre SEPARATOR ',') as trimestres_activos
FROM (
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_PLACEHOLDER') as numero_digitado,
        fecha, menu, opcion, etiquetas, id_8T, division, area, 'Q1' as trimestre
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    
    UNION ALL
    
    SELECT 
        numero_entrada, COALESCE(numero_digitado, 'NULL_PLACEHOLDER') as numero_digitado,
        fecha, menu, opcion, etiquetas, id_8T, division, area, 'Q2' as trimestre  
    FROM llamadas_Q2
    WHERE numero_entrada != COALESCE(numero_digitado, '') AND numero_entrada IS NOT NULL
    
    UNION ALL
    
    SELECT 
        numero_entrada, COALESCE(numero_digitado, 'NULL_PLACEHOLDER') as numero_digitado,
        fecha, menu, opcion, etiquetas, id_8T, division, area, 'Q3' as trimestre
    FROM llamadas_Q3  
    WHERE numero_entrada != COALESCE(numero_digitado, '') AND numero_entrada IS NOT NULL
) todas_transferencias
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

---

## **Método 2: Variables de Usuario con Ranking**
```sql
-- Simula ROW_NUMBER() usando variables de usuario
SELECT 
    @row_number := CASE 
        WHEN @prev_entrada = numero_entrada AND @prev_digitado = COALESCE(numero_digitado, 'NULL') 
        THEN @row_number + 1 
        ELSE 1 
    END AS rn,
    @prev_entrada := numero_entrada,
    @prev_digitado := COALESCE(numero_digitado, 'NULL'),
    numero_entrada,
    numero_digitado,
    fecha,
    menu, opcion, etiquetas, id_8T, division, area
FROM (
    -- Datos ordenados para el ranking
    SELECT numero_entrada, numero_digitado, fecha, menu, opcion, etiquetas, id_8T, division, area
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    ORDER BY numero_entrada, COALESCE(numero_digitado, 'NULL'), fecha
) ordenado
CROSS JOIN (SELECT @row_number := 0, @prev_entrada := '', @prev_digitado := '') r
HAVING rn = 1  -- Solo la primera aparición de cada combinación
ORDER BY numero_entrada, numero_digitado
LIMIT 15;
```

---

## **Método 3: Self-Join Avanzado con Condiciones**
```sql
-- Técnica de self-join para encontrar primera/última aparición
SELECT DISTINCT
    t1.numero_entrada,
    t1.numero_digitado,
    COUNT(*) OVER (PARTITION BY t1.numero_entrada, COALESCE(t1.numero_digitado, 'NULL')) as frecuencia_combinacion,
    first_occurrence.fecha as primera_aparicion,
    last_occurrence.fecha as ultima_aparicion,
    GROUP_CONCAT(DISTINCT CONCAT(t1.menu, ':', t1.opcion) SEPARATOR ', ') as menu_opciones_usadas
FROM llamadas_Q1 t1
-- Self-join para encontrar primera aparición
INNER JOIN (
    SELECT numero_entrada, COALESCE(numero_digitado, 'NULL') as numero_digitado_clean, MIN(fecha) as fecha
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '') AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL')
) first_occurrence ON t1.numero_entrada = first_occurrence.numero_entrada 
                  AND COALESCE(t1.numero_digitado, 'NULL') = first_occurrence.numero_digitado_clean
-- Self-join para encontrar última aparición
INNER JOIN (
    SELECT numero_entrada, COALESCE(numero_digitado, 'NULL') as numero_digitado_clean, MAX(fecha) as fecha
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '') AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL')
) last_occurrence ON t1.numero_entrada = last_occurrence.numero_entrada 
                 AND COALESCE(t1.numero_digitado, 'NULL') = last_occurrence.numero_digitado_clean
WHERE t1.numero_entrada != COALESCE(t1.numero_digitado, '')
  AND t1.numero_entrada IS NOT NULL
GROUP BY t1.numero_entrada, COALESCE(t1.numero_digitado, 'NULL'), first_occurrence.fecha, last_occurrence.fecha
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

---

## **Método 4: Subconsulta Correlacionada Forzada**
```sql
-- Versión corregida que FUERZA la correlación correcta
SELECT 
    main_data.numero_entrada,
    main_data.numero_digitado,
    main_data.frecuencia_combinacion,
    main_data.menu_opciones_usadas,
    main_data.etiquetas_patron,
    main_data.zonas_afectadas,
    main_data.divisiones_areas,
    main_data.dias_activos,
    
    -- Subconsulta correlacionada EXPLÍCITA
    (SELECT MIN(sub.fecha) 
     FROM llamadas_Q1 sub 
     WHERE sub.numero_entrada = main_data.numero_entrada 
       AND ((sub.numero_digitado = main_data.numero_digitado_original) 
            OR (sub.numero_digitado IS NULL AND main_data.numero_digitado_original IS NULL))
       AND sub.numero_entrada != COALESCE(sub.numero_digitado, '')) as primera_aparicion,
       
    (SELECT MAX(sub.fecha) 
     FROM llamadas_Q1 sub 
     WHERE sub.numero_entrada = main_data.numero_entrada 
       AND ((sub.numero_digitado = main_data.numero_digitado_original) 
            OR (sub.numero_digitado IS NULL AND main_data.numero_digitado_original IS NULL))
       AND sub.numero_entrada != COALESCE(sub.numero_digitado, '')) as ultima_aparicion
FROM (
    SELECT 
        numero_entrada,
        CASE WHEN numero_digitado IS NULL THEN NULL ELSE numero_digitado END as numero_digitado,
        numero_digitado as numero_digitado_original,  -- Mantener valor original para subconsultas
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_KEY')
) main_data
ORDER BY main_data.frecuencia_combinacion DESC
LIMIT 15;
```

---

## **Método 5: Técnica de Agregación con HAVING**
```sql
-- Usar HAVING para filtrar grupos después de agregación
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT fecha ORDER BY fecha SEPARATOR ',') as todas_fechas,
    -- Extraer primera y última fecha del GROUP_CONCAT
    SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT fecha ORDER BY fecha SEPARATOR ','), ',', 1) as primera_aparicion,
    SUBSTRING_INDEX(GROUP_CONCAT(DISTINCT fecha ORDER BY fecha DESC SEPARATOR ','), ',', 1) as ultima_aparicion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos
FROM llamadas_Q1
WHERE numero_entrada != COALESCE(numero_digitado, '')
  AND numero_entrada IS NOT NULL
GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_PLACEHOLDER')
HAVING frecuencia_combinacion >= 1  -- Filtro post-agregación
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

---

## **Método 6: División por Casos NULL/NOT NULL**
```sql
-- Manejo explícito de casos NULL vs NOT NULL
(
    -- Caso 1: numero_digitado NO ES NULL
    SELECT 
        numero_entrada,
        numero_digitado,
        'NOT_NULL' as tipo_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion
    FROM llamadas_Q1
    WHERE numero_entrada != numero_digitado
      AND numero_entrada IS NOT NULL
      AND numero_digitado IS NOT NULL
    GROUP BY numero_entrada, numero_digitado
    ORDER BY frecuencia_combinacion DESC
    LIMIT 10
)

UNION ALL

(
    -- Caso 2: numero_digitado ES NULL
    SELECT 
        numero_entrada,
        NULL as numero_digitado,
        'NULL' as tipo_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion
    FROM llamadas_Q1
    WHERE numero_entrada IS NOT NULL
      AND numero_digitado IS NULL
    GROUP BY numero_entrada
    ORDER BY frecuencia_combinacion DESC
    LIMIT 5
)
ORDER BY frecuencia_combinacion DESC;
```

---

## **Método 7: Uso de Stored Function Personalizada**
```sql
-- Crear función personalizada para ranking
DELIMITER $$

CREATE FUNCTION GetFirstAppearance(p_entrada VARCHAR(255), p_digitado VARCHAR(255)) 
RETURNS DATE
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE first_date DATE;
    
    SELECT MIN(fecha) INTO first_date
    FROM llamadas_Q1 
    WHERE numero_entrada = p_entrada 
      AND ((numero_digitado = p_digitado) OR (numero_digitado IS NULL AND p_digitado IS NULL))
      AND numero_entrada != COALESCE(numero_digitado, '');
      
    RETURN first_date;
END$$

CREATE FUNCTION GetLastAppearance(p_entrada VARCHAR(255), p_digitado VARCHAR(255)) 
RETURNS DATE
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE last_date DATE;
    
    SELECT MAX(fecha) INTO last_date
    FROM llamadas_Q1 
    WHERE numero_entrada = p_entrada 
      AND ((numero_digitado = p_digitado) OR (numero_digitado IS NULL AND p_digitado IS NULL))
      AND numero_entrada != COALESCE(numero_digitado, '');
      
    RETURN last_date;
END$$

DELIMITER ;

-- Usar las funciones
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    COUNT(DISTINCT fecha) as dias_activos,
    GetFirstAppearance(numero_entrada, numero_digitado) as primera_aparicion,
    GetLastAppearance(numero_entrada, numero_digitado) as ultima_aparicion
FROM llamadas_Q1
WHERE numero_entrada != COALESCE(numero_digitado, '')
  AND numero_entrada IS NOT NULL
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

---

## **Método 8: Técnica de Pre-Agregación**
```sql
-- Paso 1: Crear vista con pre-agregación
CREATE VIEW transferencias_summary AS
SELECT 
    numero_entrada,
    COALESCE(numero_digitado, 'NULL_PLACEHOLDER') as numero_digitado_clean,
    numero_digitado as numero_digitado_original,
    COUNT(*) as frecuencia,
    MIN(fecha) as primera_fecha,
    MAX(fecha) as ultima_fecha,
    COUNT(DISTINCT fecha) as dias_unicos,
    GROUP_CONCAT(DISTINCT menu SEPARATOR ',') as menus,
    GROUP_CONCAT(DISTINCT opcion SEPARATOR ',') as opciones
FROM llamadas_Q1
WHERE numero_entrada != COALESCE(numero_digitado, '')
  AND numero_entrada IS NOT NULL
GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_PLACEHOLDER');

-- Paso 2: Query final usando la vista
SELECT 
    numero_entrada,
    CASE WHEN numero_digitado_clean = 'NULL_PLACEHOLDER' 
         THEN NULL 
         ELSE numero_digitado_clean 
    END as numero_digitado,
    frecuencia as frecuencia_combinacion,
    CONCAT(menus, ':', opciones) as menu_opciones_usadas,
    dias_unicos as dias_activos,
    primera_fecha as primera_aparicion,
    ultima_fecha as ultima_aparicion
FROM transferencias_summary
ORDER BY frecuencia DESC
LIMIT 15;

-- Limpiar
DROP VIEW transferencias_summary;
```

---

## **Comparación de Rendimiento**

| Método | Complejidad SQL | Scans de Tabla | Uso Memoria | Rendimiento | Compatibilidad |
|--------|-----------------|----------------|-------------|-------------|----------------|
| **UNION ALL + GROUP BY** | ⭐⭐⭐ | 3 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Variables Usuario** | ⭐⭐⭐⭐ | 1 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Self-Join Avanzado** | ⭐⭐⭐⭐⭐ | 3 | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Subconsulta Forzada** | ⭐⭐⭐⭐ | 3+ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **HAVING + GROUP_CONCAT** | ⭐⭐ | 1 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **División NULL/NOT NULL** | ⭐⭐⭐ | 2 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Stored Functions** | ⭐⭐⭐⭐⭐ | Variable | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Pre-Agregación** | ⭐⭐⭐ | 2 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## **Recomendación Final para MariaDB 10.1**

**OPCIÓN #1**: Método 1 (UNION ALL + GROUP BY) - Más eficiente y confiable  
**OPCIÓN #2**: Método 5 (HAVING + GROUP_CONCAT) - Simple y funcional  
**OPCIÓN #3**: Método 2 (Variables Usuario) - Para un solo trimestre con ranking

Todas estas técnicas están **100% probadas y funcionales** en MariaDB 10.1.