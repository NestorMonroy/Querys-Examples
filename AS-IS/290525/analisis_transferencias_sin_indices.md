# Análisis de Transferencias - MariaDB 10.1 Sin Índices
## Optimización para 3 Tablas Trimestrales Sin Índices

> **ESCENARIO**: MariaDB 10.1, sin índices, 3 tablas (`llamadas_Q1`, `llamadas_Q2`, `llamadas_Q3`)  
> **OBJETIVO**: Máximo rendimiento sin poder crear índices

---

## **Método 1: UNION ALL + Agrupación Simple (RECOMENDADO)**
```sql
-- Une las 3 tablas primero, luego agrupa una sola vez
-- VENTAJA: Un solo GROUP BY al final, mínimas operaciones
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) ORDER BY menu, opcion SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas ORDER BY etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T ORDER BY id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) ORDER BY division, area SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_aparicion,
    MAX(fecha) as ultima_aparicion,
    -- Indicar de qué trimestres viene cada combinación
    GROUP_CONCAT(DISTINCT trimestre ORDER BY trimestre SEPARATOR ',') as trimestres_activos
FROM (
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        fecha,
        menu,
        opcion,
        etiquetas,
        id_8T,
        division,
        area,
        'Q1' as trimestre
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    
    UNION ALL
    
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        fecha,
        menu,
        opcion,
        etiquetas,
        id_8T,
        division,
        area,
        'Q2' as trimestre
    FROM llamadas_Q2
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    
    UNION ALL
    
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        fecha,
        menu,
        opcion,
        etiquetas,
        id_8T,
        division,
        area,
        'Q3' as trimestre
    FROM llamadas_Q3
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
) todas_transferencias
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

**Rendimiento**: ⭐⭐⭐⭐⭐  
**Por qué es el mejor**: Un solo GROUP BY final, filtros en subconsultas, mínimo procesamiento

---

## **Método 2: Tabla Temporal Unificada (SEGUNDA OPCIÓN)**
```sql
-- Paso 1: Crear tabla temporal con TODAS las transferencias
CREATE TEMPORARY TABLE temp_todas_transferencias AS
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        fecha,
        menu,
        opcion,
        etiquetas,
        id_8T,
        division,
        area,
        'Q1' as trimestre
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    
    UNION ALL
    
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE'),
        fecha,
        menu,
        opcion,
        etiquetas,
        id_8T,
        division,
        area,
        'Q2'
    FROM llamadas_Q2
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    
    UNION ALL
    
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE'),
        fecha,
        menu,
        opcion,
        etiquetas,
        id_8T,
        division,
        area,
        'Q3'
    FROM llamadas_Q3
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL;

-- Paso 2: Query simple sobre tabla temporal
SELECT 
    numero_entrada,
    CASE WHEN numero_digitado = 'NULL_VALUE' THEN NULL ELSE numero_digitado END as numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_aparicion,
    MAX(fecha) as ultima_aparicion,
    GROUP_CONCAT(DISTINCT trimestre SEPARATOR ',') as trimestres_activos
FROM temp_todas_transferencias
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;

-- Paso 3: Limpiar
DROP TEMPORARY TABLE temp_todas_transferencias;
```

**Rendimiento**: ⭐⭐⭐⭐  
**Ventaja**: Datos filtrados una sola vez, query final muy simple

---

## **Método 3: Subconsultas por Tabla con UNION ALL**
```sql
-- Cada tabla se procesa independientemente, luego se combinan
SELECT 
    numero_entrada,
    numero_digitado,
    SUM(frecuencia_combinacion) as frecuencia_combinacion,
    -- Combinar resultados de las 3 tablas
    GROUP_CONCAT(DISTINCT menu_opciones_usadas SEPARATOR ' | ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas_patron SEPARATOR ' | ') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT zonas_afectadas SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT divisiones_areas SEPARATOR ' | ') as divisiones_areas,
    SUM(dias_activos) as total_dias_activos,
    MIN(primera_aparicion) as primera_aparicion,
    MAX(ultima_aparicion) as ultima_aparicion,
    GROUP_CONCAT(DISTINCT trimestre_origen SEPARATOR ',') as trimestres_activos
FROM (
    -- Q1
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion,
        'Q1' as trimestre_origen
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_VALUE')
    
    UNION ALL
    
    -- Q2
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion,
        'Q2' as trimestre_origen
    FROM llamadas_Q2
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_VALUE')
    
    UNION ALL
    
    -- Q3
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion,
        'Q3' as trimestre_origen
    FROM llamadas_Q3
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_VALUE')
) resultados_por_trimestre
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

**Rendimiento**: ⭐⭐⭐  
**Problema**: Múltiples GROUP BY, más procesamiento

---

## **Método 4: Análisis por Tabla Individual**
```sql
-- Para casos donde quieres ver cada trimestre por separado primero
-- Útil para comparar comportamiento entre trimestres

-- Query para ejecutar por cada tabla:
SELECT 
    'Q1' as trimestre,
    numero_entrada,
    COALESCE(numero_digitado, 'NULL') as numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_aparicion,
    MAX(fecha) as ultima_aparicion
FROM llamadas_Q1
WHERE numero_entrada != COALESCE(numero_digitado, '')
  AND numero_entrada IS NOT NULL
GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL')
ORDER BY frecuencia_combinacion DESC
LIMIT 5;

-- Cambiar tabla y trimestre para Q2 y Q3
```

**Rendimiento**: ⭐⭐⭐⭐  
**Uso**: Para análisis exploratorio por trimestre

---

## **Método 5: Stored Procedure Optimizado**
```sql
DELIMITER $$

CREATE PROCEDURE AnalisisTransferenciasTrimestral()
BEGIN
    -- Crear tabla temporal unificada
    CREATE TEMPORARY TABLE temp_union_transferencias AS
        SELECT 
            numero_entrada,
            COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
            fecha,
            menu,
            opcion,
            etiquetas,
            id_8T,
            division,
            area,
            'Q1' as trimestre
        FROM llamadas_Q1
        WHERE numero_entrada != COALESCE(numero_digitado, '')
          AND numero_entrada IS NOT NULL
        
        UNION ALL
        
        SELECT 
            numero_entrada,
            COALESCE(numero_digitado, 'NULL_VALUE'),
            fecha,
            menu,
            opcion,
            etiquetas,
            id_8T,
            division,
            area,
            'Q2'
        FROM llamadas_Q2
        WHERE numero_entrada != COALESCE(numero_digitado, '')
          AND numero_entrada IS NOT NULL
        
        UNION ALL
        
        SELECT 
            numero_entrada,
            COALESCE(numero_digitado, 'NULL_VALUE'),
            fecha,
            menu,
            opcion,
            etiquetas,
            id_8T,
            division,
            area,
            'Q3'
        FROM llamadas_Q3
        WHERE numero_entrada != COALESCE(numero_digitado, '')
          AND numero_entrada IS NOT NULL;
    
    -- Resultado final
    SELECT 
        numero_entrada,
        CASE WHEN numero_digitado = 'NULL_VALUE' THEN NULL ELSE numero_digitado END as numero_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion,
        GROUP_CONCAT(DISTINCT trimestre ORDER BY trimestre SEPARATOR ',') as trimestres_activos
    FROM temp_union_transferencias
    GROUP BY numero_entrada, numero_digitado
    ORDER BY frecuencia_combinacion DESC
    LIMIT 15;
    
    -- Limpiar
    DROP TEMPORARY TABLE temp_union_transferencias;
END$$

DELIMITER ;

-- Uso:
CALL AnalisisTransferenciasTrimestral();
```

**Rendimiento**: ⭐⭐⭐⭐  
**Ventaja**: Reutilizable, encapsula la lógica

---

## **Método 6: Filtrado Agresivo Antes del UNION**
```sql
-- Solo transfiere los campos mínimos necesarios
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_aparicion,
    MAX(fecha) as ultima_aparicion,
    GROUP_CONCAT(DISTINCT trimestre_origen ORDER BY trimestre_origen) as trimestres_activos,
    -- Detalles adicionales en subconsulta separada si es necesario
    (SELECT GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ')
     FROM (
         SELECT menu, opcion FROM llamadas_Q1 WHERE numero_entrada = outer.numero_entrada AND COALESCE(numero_digitado, 'NULL_VALUE') = outer.numero_digitado
         UNION ALL
         SELECT menu, opcion FROM llamadas_Q2 WHERE numero_entrada = outer.numero_entrada AND COALESCE(numero_digitado, 'NULL_VALUE') = outer.numero_digitado
         UNION ALL
         SELECT menu, opcion FROM llamadas_Q3 WHERE numero_entrada = outer.numero_entrada AND COALESCE(numero_digitado, 'NULL_VALUE') = outer.numero_digitado
     ) sub
    ) as menu_opciones_usadas
FROM (
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        fecha,
        'Q1' as trimestre_origen
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    
    UNION ALL
    
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE'),
        fecha,
        'Q2'
    FROM llamadas_Q2
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    
    UNION ALL
    
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE'),
        fecha,
        'Q3'
    FROM llamadas_Q3
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
) outer
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

**Rendimiento**: ⭐⭐⭐⭐  
**Problema**: Subconsultas adicionales pueden ser costosas

---

## **Comparación de Rendimiento Sin Índices**

| Método | Full Table Scans | GROUP BY Operations | Memory Usage | Overall Performance |
|--------|------------------|---------------------|--------------|-------------------|
| **UNION ALL + Agrupación** | 3 | 1 | Medio | ⭐⭐⭐⭐⭐ |
| **Tabla Temporal** | 3 | 1 | Alto | ⭐⭐⭐⭐ |
| **Subconsultas por Tabla** | 3 | 4 | Muy Alto | ⭐⭐⭐ |
| **Por Tabla Individual** | 1 por query | 1 por query | Bajo | ⭐⭐⭐⭐ |
| **Stored Procedure** | 3 | 1 | Alto | ⭐⭐⭐⭐ |
| **Filtrado Agresivo** | 6+ | 1+ | Medio | ⭐⭐⭐⭐ |

---

## **Recomendación Final**

**Para máximo rendimiento sin índices**: **Método 1 (UNION ALL + Agrupación Simple)**

**Razones:**
1. **Un solo GROUP BY** al final vs múltiples GROUP BY
2. **Filtros aplicados en subconsultas** - reduce datos desde el inicio
3. **Mínimo procesamiento** de agregaciones
4. **Menos uso de memoria temporal** vs tabla temporal
5. **Resultado más completo** incluyendo información de trimestres

**Si necesitas reutilización**: Método 5 (Stored Procedure)  
**Si memoria es limitada**: Método 4 (Por tabla individual) ejecutado 3 veces