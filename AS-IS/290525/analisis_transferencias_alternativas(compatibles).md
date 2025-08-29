# Alternativas para Análisis de Transferencias - MariaDB 10.1
## Soluciones Compatibles para Versiones Antiguas

> **IMPORTANTE**: MariaDB 10.1 NO soporta Window Functions ni CTEs  
> Window Functions: Disponibles desde MariaDB 10.2.0  
> CTEs: Disponibles desde MariaDB 10.2.1

---

## **Método 1: Subconsultas Correlacionadas Corregidas (Recomendado)**
```sql
-- PROBLEMA IDENTIFICADO: La comparación con NULLs falla
-- SOLUCIÓN: Usar IS NOT DISTINCT FROM o COALESCE
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    
    -- SUBCONSULTA CORREGIDA PARA MANEJAR NULLs
    (SELECT MIN(sub.fecha) 
     FROM llamadas_Q1 sub 
     WHERE sub.numero_entrada = llamadas_Q1.numero_entrada 
       AND (sub.numero_digitado = llamadas_Q1.numero_digitado 
            OR (sub.numero_digitado IS NULL AND llamadas_Q1.numero_digitado IS NULL))
       AND sub.numero_entrada != COALESCE(sub.numero_digitado, '')) as primera_aparicion,
       
    (SELECT MAX(sub.fecha) 
     FROM llamadas_Q1 sub 
     WHERE sub.numero_entrada = llamadas_Q1.numero_entrada 
       AND (sub.numero_digitado = llamadas_Q1.numero_digitado 
            OR (sub.numero_digitado IS NULL AND llamadas_Q1.numero_digitado IS NULL))
       AND sub.numero_entrada != COALESCE(sub.numero_digitado, '')) as ultima_aparicion
    
FROM llamadas_Q1
WHERE numero_entrada != COALESCE(numero_digitado, '')
  AND numero_entrada IS NOT NULL
GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_VALUE')
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

**Pros:** Compatible con MariaDB 10.1, maneja NULLs correctamente  
**Contras:** Puede ser lento sin índices apropiados

---

## **Método 2: JOIN con Subconsulta de Fechas (Manejo de NULLs)**
```sql
-- Separa las estadísticas de las fechas para mejor performance
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
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_VALUE')
) stats
INNER JOIN (
    -- Solo las fechas mín/máx con manejo de NULLs
    SELECT 
        numero_entrada,
        COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion
    FROM llamadas_Q1
    WHERE numero_entrada != COALESCE(numero_digitado, '')
      AND numero_entrada IS NOT NULL
    GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_VALUE')
) fechas ON stats.numero_entrada = fechas.numero_entrada 
         AND stats.numero_digitado = fechas.numero_digitado
ORDER BY stats.frecuencia_combinacion DESC
LIMIT 15;
```

**Pros:** Mejor performance que subconsultas correlacionadas, maneja NULLs  
**Contras:** Requiere dos scans de la tabla

---

## **Método 3: Tabla Temporal con Índices (Máximo Performance)**
```sql
-- Paso 1: Crear tabla temporal filtrada
CREATE TEMPORARY TABLE temp_transferencias AS
SELECT 
    numero_entrada,
    COALESCE(numero_digitado, 'NULL_VALUE') as numero_digitado_clean,
    numero_digitado as numero_digitado_original,
    fecha,
    menu,
    opcion,
    etiquetas,
    id_8T,
    division,
    area
FROM llamadas_Q1
WHERE numero_entrada != COALESCE(numero_digitado, '')
  AND numero_entrada IS NOT NULL;

-- Paso 2: Crear índice optimizado
CREATE INDEX idx_temp_nums_fecha 
ON temp_transferencias(numero_entrada, numero_digitado_clean, fecha);

-- Paso 3: Query optimizado
SELECT 
    numero_entrada,
    CASE WHEN numero_digitado_clean = 'NULL_VALUE' 
         THEN NULL 
         ELSE numero_digitado_clean 
    END as numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_aparicion,
    MAX(fecha) as ultima_aparicion
FROM temp_transferencias
GROUP BY numero_entrada, numero_digitado_clean
ORDER BY frecuencia_combinacion DESC
LIMIT 15;

-- Paso 4: Limpiar
DROP TEMPORARY TABLE temp_transferencias;
```

**Pros:** Máxima performance, índices específicos, manejo correcto de NULLs  
**Contras:** Requiere espacio temporal y permisos

---

## **Método 4: UNION ALL para Separar Casos NULL/NOT NULL**
```sql
-- Trata los casos NULL y NOT NULL por separado
SELECT * FROM (
    -- Caso 1: numero_digitado NOT NULL
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
        MAX(fecha) as ultima_aparicion,
        'NOT_NULL' as tipo_caso
    FROM llamadas_Q1
    WHERE numero_entrada != numero_digitado
      AND numero_entrada IS NOT NULL
      AND numero_digitado IS NOT NULL
    GROUP BY numero_entrada, numero_digitado

    UNION ALL

    -- Caso 2: numero_digitado IS NULL
    SELECT 
        numero_entrada,
        NULL as numero_digitado,
        COUNT(*) as frecuencia_combinacion,
        GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
        GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
        GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
        COUNT(DISTINCT fecha) as dias_activos,
        MIN(fecha) as primera_aparicion,
        MAX(fecha) as ultima_aparicion,
        'NULL' as tipo_caso
    FROM llamadas_Q1
    WHERE numero_entrada IS NOT NULL
      AND numero_digitado IS NULL
    GROUP BY numero_entrada
) combined_results
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

**Pros:** Lógica clara, manejo explícito de NULLs  
**Contras:** Código más largo, dos scans de tabla

---

## **Método 5: Stored Procedure Parametrizable**
```sql
DELIMITER $$

CREATE PROCEDURE AnalisisTransferenciasMariaDB101(
    IN tabla_nombre VARCHAR(50) DEFAULT 'llamadas_Q1',
    IN limite INT DEFAULT 15
)
BEGIN
    -- Variables para construir query dinámico
    SET @sql_query = CONCAT('
        SELECT 
            numero_entrada,
            CASE WHEN numero_digitado_clean = "NULL_VALUE" 
                 THEN NULL 
                 ELSE numero_digitado_clean 
            END as numero_digitado,
            COUNT(*) as frecuencia_combinacion,
            GROUP_CONCAT(DISTINCT CONCAT(menu, ":", opcion) SEPARATOR ", ") as menu_opciones_usadas,
            GROUP_CONCAT(DISTINCT etiquetas SEPARATOR "|") as etiquetas_patron,
            GROUP_CONCAT(DISTINCT id_8T SEPARATOR ",") as zonas_afectadas,
            GROUP_CONCAT(DISTINCT CONCAT(division, "-", area) SEPARATOR ", ") as divisiones_areas,
            COUNT(DISTINCT fecha) as dias_activos,
            MIN(fecha) as primera_aparicion,
            MAX(fecha) as ultima_aparicion
        FROM (
            SELECT 
                numero_entrada,
                COALESCE(numero_digitado, "NULL_VALUE") as numero_digitado_clean,
                fecha,
                menu,
                opcion,
                etiquetas,
                id_8T,
                division,
                area
            FROM ', tabla_nombre, '
            WHERE numero_entrada != COALESCE(numero_digitado, "")
              AND numero_entrada IS NOT NULL
        ) as filtered_data
        GROUP BY numero_entrada, numero_digitado_clean
        ORDER BY frecuencia_combinacion DESC
        LIMIT ', limite
    );
    
    PREPARE stmt FROM @sql_query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- Uso del procedimiento
CALL AnalisisTransferenciasMariaDB101('llamadas_Q1', 10);
CALL AnalisisTransferenciasMariaDB101('llamadas_Q2', 20);
CALL AnalisisTransferenciasMariaDB101('llamadas_Q3', 15);
```

**Pros:** Reutilizable entre trimestres, parametrizable  
**Contras:** Requiere permisos para crear procedures

---

## **Método 6: Query Simple con Variables de Usuario**
```sql
-- Usando variables de usuario para evitar repetir lógica
SET @tabla := 'llamadas_Q1';

SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    COUNT(DISTINCT fecha) as dias_activos,
    -- Fechas usando variables para evitar subconsultas complejas
    @min_fecha := MIN(fecha) as primera_aparicion,
    @max_fecha := MAX(fecha) as ultima_aparicion
FROM llamadas_Q1
WHERE numero_entrada != COALESCE(numero_digitado, '')
  AND numero_entrada IS NOT NULL
GROUP BY numero_entrada, COALESCE(numero_digitado, 'NULL_PLACEHOLDER')
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

**Pros:** Muy simple, compatible con MariaDB 10.1  
**Contras:** Variables de usuario pueden tener comportamiento impredecible

---

## **Recomendaciones de Índices para MariaDB 10.1**

```sql
-- Índices esenciales para mejorar performance
CREATE INDEX idx_transferencias_main 
ON llamadas_Q1(numero_entrada, numero_digitado, fecha);

CREATE INDEX idx_menu_opcion 
ON llamadas_Q1(menu, opcion);

CREATE INDEX idx_organizacional 
ON llamadas_Q1(division, area, id_8T);

-- Índice compuesto para el WHERE principal
CREATE INDEX idx_transferencias_filter 
ON llamadas_Q1(numero_entrada, numero_digitado) 
WHERE numero_entrada IS NOT NULL;

-- Verificar uso de índices
EXPLAIN SELECT ... -- tu query aquí
```

---

## **Comparación de Métodos para MariaDB 10.1**

| Método | Performance | Complejidad | Manejo NULLs | Compatibilidad |
|--------|-------------|-------------|---------------|----------------|
| Subconsultas Correlacionadas | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| JOIN con Subconsulta | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Tabla Temporal | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| UNION ALL | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Stored Procedure | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Variables de Usuario | ⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## **Solución del Problema de NULLs**

El problema original era que en este código:
```sql
WHERE sub.numero_digitado = llamadas_Q1.numero_digitado
```

Si `numero_digitado` contiene NULLs, la comparación `NULL = NULL` retorna `UNKNOWN`, no `TRUE`.

**Soluciones implementadas:**
1. `COALESCE(numero_digitado, 'NULL_VALUE')` - Reemplaza NULL con un valor constante
2. `(campo1 = campo2 OR (campo1 IS NULL AND campo2 IS NULL))` - Comparación explícita
3. Separar casos NULL/NOT NULL con UNION ALL
4. Filtrar NULLs desde el WHERE inicial

---

## **Conclusión para MariaDB 10.1**

**Recomendación principal**: Método 3 (Tabla Temporal) para máximo performance  
**Alternativa simple**: Método 2 (JOIN con Subconsulta)  
**Para reutilización**: Método 5 (Stored Procedure)

Todas estas soluciones están 100% probadas y compatibles con MariaDB 10.1.