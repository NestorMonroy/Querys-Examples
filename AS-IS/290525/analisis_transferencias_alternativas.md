# Alternativas para Análisis de Transferencias/Enrutamiento
## MariaDB 10.1 - Query Optimization

---

## **Método 1: Subconsultas Correlacionadas (Recomendado)**
```sql
-- VENTAJAS: Eficiente, claro, aprovecha índices
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    
    -- Fechas específicas por combinación
    (SELECT MIN(sub.fecha) 
     FROM llamadas_Q1 sub 
     WHERE sub.numero_entrada = llamadas_Q1.numero_entrada 
       AND sub.numero_digitado = llamadas_Q1.numero_digitado) as primera_aparicion,
       
    (SELECT MAX(sub.fecha) 
     FROM llamadas_Q1 sub 
     WHERE sub.numero_entrada = llamadas_Q1.numero_entrada 
       AND sub.numero_digitado = llamadas_Q1.numero_digitado) as ultima_aparicion
    
FROM llamadas_Q1
WHERE numero_entrada != numero_digitado 
  AND numero_digitado IS NOT NULL
  AND numero_entrada IS NOT NULL
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

**Pros:** Eficiente, legible, MariaDB lo optimiza bien  
**Contras:** Puede ser lento en tablas muy grandes sin índices

---

## **Método 2: Window Functions (Solo si MariaDB soporta)**
```sql
-- NOTA: Verificar compatibilidad con MariaDB 10.1
-- Algunas versiones pueden no soportar todas las window functions
SELECT 
    numero_entrada,
    numero_digitado,
    frecuencia_combinacion,
    menu_opciones_usadas,
    etiquetas_patron,
    zonas_afectadas,
    divisiones_areas,
    dias_activos,
    MIN(fecha) OVER (PARTITION BY numero_entrada, numero_digitado) as primera_aparicion,
    MAX(fecha) OVER (PARTITION BY numero_entrada, numero_digitado) as ultima_aparicion
FROM (
    SELECT 
        numero_entrada,
        numero_digitado,
        fecha,
        COUNT(*) OVER (PARTITION BY numero_entrada, numero_digitado) as frecuencia_combinacion,
        STRING_AGG(DISTINCT CONCAT(menu, ':', opcion), ', ') OVER (PARTITION BY numero_entrada, numero_digitado) as menu_opciones_usadas,
        STRING_AGG(DISTINCT etiquetas, '|') OVER (PARTITION BY numero_entrada, numero_digitado) as etiquetas_patron,
        STRING_AGG(DISTINCT id_8T, ',') OVER (PARTITION BY numero_entrada, numero_digitado) as zonas_afectadas,
        STRING_AGG(DISTINCT CONCAT(division, '-', area), ', ') OVER (PARTITION BY numero_entrada, numero_digitado) as divisiones_areas,
        COUNT(DISTINCT fecha) OVER (PARTITION BY numero_entrada, numero_digitado) as dias_activos,
        ROW_NUMBER() OVER (PARTITION BY numero_entrada, numero_digitado ORDER BY fecha) as rn
    FROM llamadas_Q1
    WHERE numero_entrada != numero_digitado 
      AND numero_digitado IS NOT NULL
) ranked
WHERE rn = 1
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

**Pros:** Muy eficiente para análisis complejos  
**Contras:** Compatibilidad limitada en MariaDB 10.1

---

## **Método 3: CTE (Common Table Expression)**
```sql
-- Divide el problema en pasos más claros
WITH transferencias AS (
    SELECT 
        numero_entrada,
        numero_digitado,
        fecha,
        menu,
        opcion,
        etiquetas,
        id_8T,
        division,
        area
    FROM llamadas_Q1
    WHERE numero_entrada != numero_digitado 
      AND numero_digitado IS NOT NULL
      AND numero_entrada IS NOT NULL
),
stats_basicas AS (
    SELECT 
        numero_entrada,
        numero_digitado,
        COUNT(*) as frecuencia_combinacion,
        COUNT(DISTINCT fecha) as dias_activos,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas
    FROM transferencias
    GROUP BY numero_entrada, numero_digitado
),
fechas_extremas AS (
    SELECT 
        numero_entrada,
        numero_digitado,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion
    FROM transferencias
    GROUP BY numero_entrada, numero_digitado
)
SELECT 
    sb.numero_entrada,
    sb.numero_digitado,
    sb.frecuencia_combinacion,
    sb.menu_opciones_usadas,
    sb.etiquetas_patron,
    sb.zonas_afectadas,
    sb.divisiones_areas,
    sb.dias_activos,
    fe.primera_aparicion,
    fe.ultima_aparicion
FROM stats_basicas sb
INNER JOIN fechas_extremas fe 
    ON sb.numero_entrada = fe.numero_entrada 
    AND sb.numero_digitado = fe.numero_digitado
ORDER BY sb.frecuencia_combinacion DESC
LIMIT 15;
```

**Pros:** Muy legible, fácil de debuggear, modular  
**Contras:** Puede crear múltiples scans de la tabla

---

## **Método 4: Tabla Temporal**
```sql
-- Paso 1: Crear tabla temporal con transferencias
CREATE TEMPORARY TABLE temp_transferencias AS
SELECT 
    numero_entrada,
    numero_digitado,
    fecha,
    menu,
    opcion,
    etiquetas,
    id_8T,
    division,
    area
FROM llamadas_Q1
WHERE numero_entrada != numero_digitado 
  AND numero_digitado IS NOT NULL
  AND numero_entrada IS NOT NULL;

-- Paso 2: Crear índice en la tabla temporal
CREATE INDEX idx_temp_num_fecha ON temp_transferencias(numero_entrada, numero_digitado, fecha);

-- Paso 3: Query principal optimizado
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_aparicion,
    MAX(fecha) as ultima_aparicion
FROM temp_transferencias
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;

-- Paso 4: Limpiar
DROP TEMPORARY TABLE temp_transferencias;
```

**Pros:** Máximo control, índices específicos, debugging fácil  
**Contras:** Requiere permisos para crear tablas, más código

---

## **Método 5: JOIN con Subconsulta de Fechas**
```sql
-- Une estadísticas generales con fechas específicas
SELECT 
    stats.numero_entrada,
    stats.numero_digitado,
    stats.frecuencia_combinacion,
    stats.menu_opciones_usadas,
    stats.etiquetas_patron,
    stats.zonas_afectadas,
    stats.divisiones_areas,
    stats.dias_activos,
    fechas.primera_aparicion,
    fechas.ultima_aparicion
FROM (
    -- Estadísticas principales
    SELECT 
        numero_entrada,
        numero_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos
    FROM llamadas_Q1
    WHERE numero_entrada != numero_digitado 
      AND numero_digitado IS NOT NULL
      AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, numero_digitado
) stats
INNER JOIN (
    -- Solo las fechas mín/máx
    SELECT 
        numero_entrada,
        numero_digitado,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion
    FROM llamadas_Q1
    WHERE numero_entrada != numero_digitado 
      AND numero_digitado IS NOT NULL
      AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, numero_digitado
) fechas ON stats.numero_entrada = fechas.numero_entrada 
         AND stats.numero_digitado = fechas.numero_digitado
ORDER BY stats.frecuencia_combinacion DESC
LIMIT 15;
```

**Pros:** Separa lógica, puede ser más eficiente en algunos casos  
**Contras:** Doble scan de la tabla, más complejo

---

## **Método 6: Stored Procedure (Para reutilización)**
```sql
DELIMITER $$

CREATE PROCEDURE AnalisisTransferencias(
    IN limite INT DEFAULT 15,
    IN tabla_nombre VARCHAR(50) DEFAULT 'llamadas_Q1'
)
BEGIN
    DECLARE sql_query TEXT;
    
    SET sql_query = CONCAT('
        SELECT 
            numero_entrada,
            numero_digitado,
            COUNT(*) as frecuencia_combinacion,
            GROUP_CONCAT(DISTINCT CONCAT(menu, ":", opcion) SEPARATOR ", ") as menu_opciones_usadas,
            GROUP_CONCAT(DISTINCT etiquetas SEPARATOR "|") as etiquetas_patron,
            GROUP_CONCAT(DISTINCT id_8T SEPARATOR ",") as zonas_afectadas,
            GROUP_CONCAT(DISTINCT CONCAT(division, "-", area) SEPARATOR ", ") as divisiones_areas,
            COUNT(DISTINCT fecha) as dias_activos,
            (SELECT MIN(sub.fecha) 
             FROM ', tabla_nombre, ' sub 
             WHERE sub.numero_entrada = ', tabla_nombre, '.numero_entrada 
               AND sub.numero_digitado = ', tabla_nombre, '.numero_digitado) as primera_aparicion,
            (SELECT MAX(sub.fecha) 
             FROM ', tabla_nombre, ' sub 
             WHERE sub.numero_entrada = ', tabla_nombre, '.numero_entrada 
               AND sub.numero_digitado = ', tabla_nombre, '.numero_digitado) as ultima_aparicion
        FROM ', tabla_nombre, '
        WHERE numero_entrada != numero_digitado 
          AND numero_digitado IS NOT NULL
          AND numero_entrada IS NOT NULL
        GROUP BY numero_entrada, numero_digitado
        ORDER BY frecuencia_combinacion DESC
        LIMIT ', limite
    );
    
    SET @sql = sql_query;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- Uso:
CALL AnalisisTransferencias(10, 'llamadas_Q1');
CALL AnalisisTransferencias(20, 'llamadas_Q2');
```

**Pros:** Reutilizable, parametrizable, consistente  
**Contras:** Requiere permisos para crear procedures

---

## **Recomendación de Índices**

Para mejorar el performance de cualquier método:

```sql
-- Índices recomendados
CREATE INDEX idx_transferencias ON llamadas_Q1(numero_entrada, numero_digitado, fecha);
CREATE INDEX idx_menu_opcion ON llamadas_Q1(menu, opcion);
CREATE INDEX idx_division_area ON llamadas_Q1(division, area);
CREATE INDEX idx_fecha ON llamadas_Q1(fecha);

-- Para verificar que se usan los índices
EXPLAIN SELECT ... -- tu query aquí
```

---

## **Comparación de Performance**

| Método | Complejidad | Performance | Mantenibilidad | Compatibilidad |
|--------|-------------|-------------|----------------|----------------|
| Subconsultas Correlacionadas | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Window Functions | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| CTE | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Tabla Temporal | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| JOIN con Subconsulta | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Stored Procedure | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## **Conclusión**

Para **MariaDB 10.1**, recomiendo:

1. **Primera opción**: Subconsultas correlacionadas con índices apropiados
2. **Para análisis complejos**: Tabla temporal con índices específicos
3. **Para reutilización**: Stored procedure
4. **Para debugging**: CTE (si está disponible)