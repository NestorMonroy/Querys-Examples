# AS-IS: Análisis de Calidad de Datos - Diagnóstico Completo de Errores

## Propósito
Identificar, cuantificar y documentar todos los problemas de calidad de datos presentes en las tablas llamadas_Q1, llamadas_Q2, llamadas_Q3 para determinar el impacto en reportes y análisis.

---

## 1. Problemas de Calidad Identificados

### **Error Crítico 1: Timestamps Invertidos**
**Descripción**: `hora_fin < hora_inicio`
**Impacto**: Cálculos de duración incorrectos, ordenamiento temporal erróneo

```sql
-- DIAGNÓSTICO: Timestamps invertidos por trimestre
SELECT 
    'llamadas_Q1' as tabla,
    COUNT(*) as total_registros,
    SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) as timestamps_invertidos,
    ROUND(SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as porcentaje_invertidos,
    
    -- Análisis de impacto por menú
    GROUP_CONCAT(DISTINCT 
        CASE WHEN hora_fin < hora_inicio THEN menu END
        ORDER BY menu LIMIT 10
    ) as menus_mas_afectados
FROM llamadas_Q1

UNION ALL

SELECT 'llamadas_Q2', COUNT(*), 
       SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END),
       ROUND(SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2),
       GROUP_CONCAT(DISTINCT CASE WHEN hora_fin < hora_inicio THEN menu END ORDER BY menu LIMIT 10)
FROM llamadas_Q2

UNION ALL

SELECT 'llamadas_Q3', COUNT(*),
       SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END),
       ROUND(SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2),
       GROUP_CONCAT(DISTINCT CASE WHEN hora_fin < hora_inicio THEN menu END ORDER BY menu LIMIT 10)
FROM llamadas_Q3;
```

### **Error Crítico 2: Fechas Base Incorrectas**
**Descripción**: Timestamps usan fecha base `01/01/1900` en lugar de fecha real
**Impacto**: Imposibilidad de cálculos temporales precisos sin corrección

```sql
-- DIAGNÓSTICO: Estructura de timestamps
SELECT 
    'Análisis_timestamps' as analisis,
    COUNT(*) as total_registros,
    COUNT(DISTINCT LEFT(hora_inicio, 10)) as fechas_diferentes_hora_inicio,
    COUNT(DISTINCT LEFT(hora_fin, 10)) as fechas_diferentes_hora_fin,
    
    -- Verificar si todas usan 01/01/1900
    SUM(CASE WHEN LEFT(hora_inicio, 10) = '01/01/1900' THEN 1 ELSE 0 END) as usa_fecha_base_inicio,
    SUM(CASE WHEN LEFT(hora_fin, 10) = '01/01/1900' THEN 1 ELSE 0 END) as usa_fecha_base_fin,
    
    -- Ejemplos de timestamps problemáticos
    GROUP_CONCAT(DISTINCT 
        CASE WHEN LEFT(hora_inicio, 10) != '01/01/1900' THEN hora_inicio END 
        LIMIT 3
    ) as ejemplos_fechas_anomalas

FROM (
    SELECT hora_inicio, hora_fin FROM llamadas_Q1
    UNION ALL
    SELECT hora_inicio, hora_fin FROM llamadas_Q2
    UNION ALL  
    SELECT hora_inicio, hora_fin FROM llamadas_Q3
) todos_timestamps;
```

### **Error Crítico 3: Campos Obligatorios Nulos**
**Descripción**: Campos esenciales con valores nulos o vacíos
**Impacto**: Registros no procesables en análisis

```sql
-- DIAGNÓSTICO: Completitud de campos críticos
SELECT 
    campo,
    tabla,
    registros_nulos,
    total_registros,
    ROUND(registros_nulos * 100.0 / total_registros, 2) as porcentaje_nulo,
    CASE 
        WHEN porcentaje_nulo > 10 THEN 'CRITICO'
        WHEN porcentaje_nulo > 5 THEN 'ALTO'
        WHEN porcentaje_nulo > 1 THEN 'MODERADO'
        ELSE 'BAJO'
    END as nivel_criticidad
FROM (
    SELECT 'numero_entrada' as campo, 'llamadas_Q1' as tabla,
           SUM(CASE WHEN numero_entrada IS NULL OR numero_entrada = '' THEN 1 ELSE 0 END) as registros_nulos,
           COUNT(*) as total_registros,
           SUM(CASE WHEN numero_entrada IS NULL OR numero_entrada = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as porcentaje_nulo
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'menu', 'llamadas_Q1',
           SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END), COUNT(*),
           SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'numero_digitado', 'llamadas_Q1',
           SUM(CASE WHEN numero_digitado IS NULL OR numero_digitado = '' THEN 1 ELSE 0 END), COUNT(*),
           SUM(CASE WHEN numero_digitado IS NULL OR numero_digitado = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'etiquetas', 'llamadas_Q1',
           SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END), COUNT(*),
           SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
    FROM llamadas_Q1
    
    -- Repetir para Q2 y Q3...
) analisis_completitud
ORDER BY porcentaje_nulo DESC;
```

---

## 2. Problemas de Consistencia

### **Error de Consistencia 1: Relación menu-opcion-etiquetas Inconsistente**
**Descripción**: Combinaciones que no siguen las reglas de negocio esperadas
**Impacto**: Dificultad para clasificar y validar interacciones

```sql
-- DIAGNÓSTICO: Inconsistencias en relaciones menu-opcion-etiquetas
WITH patrones_esperados AS (
    SELECT 
        menu,
        opcion,
        COUNT(*) as frecuencia,
        
        -- Patrones de etiquetas más comunes para esta combinación
        GROUP_CONCAT(DISTINCT etiquetas ORDER BY etiquetas) as patrones_etiquetas,
        COUNT(DISTINCT etiquetas) as variaciones_etiquetas,
        
        -- Casos donde opción no aparece en etiquetas (cuando debería)
        SUM(CASE WHEN opcion IS NOT NULL AND opcion != '' AND opcion NOT IN ('DEFAULT', '21', '1', '5', '11')
                     AND (etiquetas IS NULL OR etiquetas NOT LIKE CONCAT('%', opcion, '%'))
                THEN 1 ELSE 0 END) as casos_opcion_no_reflejada,
                
        -- Casos donde menu tipo RES-* no tiene etiquetas VSI
        SUM(CASE WHEN menu LIKE 'RES-%' AND (etiquetas IS NULL OR etiquetas NOT LIKE '%VSI%')
                THEN 1 ELSE 0 END) as casos_res_sin_vsi,
                
        -- Casos donde menu comercial tiene etiquetas complejas
        SUM(CASE WHEN menu LIKE 'comercial_%' AND etiquetas IS NOT NULL AND etiquetas != '' AND LENGTH(etiquetas) > 10
                THEN 1 ELSE 0 END) as casos_comercial_con_etiquetas_complejas

    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL
        SELECT * FROM llamadas_Q2
        UNION ALL
        SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE menu IS NOT NULL
    GROUP BY menu, opcion
    HAVING frecuencia >= 5
)
SELECT 
    menu,
    opcion,
    frecuencia,
    variaciones_etiquetas,
    casos_opcion_no_reflejada,
    casos_res_sin_vsi,
    casos_comercial_con_etiquetas_complejas,
    
    -- Nivel de inconsistencia
    CASE 
        WHEN (casos_opcion_no_reflejada + casos_res_sin_vsi + casos_comercial_con_etiquetas_complejas) > frecuencia * 0.3 
        THEN 'ALTA_INCONSISTENCIA'
        WHEN (casos_opcion_no_reflejada + casos_res_sin_vsi + casos_comercial_con_etiquetas_complejas) > frecuencia * 0.1
        THEN 'INCONSISTENCIA_MODERADA'
        ELSE 'CONSISTENTE'
    END as nivel_consistencia,
    
    LEFT(patrones_etiquetas, 100) as muestra_patrones

FROM patrones_esperados
ORDER BY (casos_opcion_no_reflejada + casos_res_sin_vsi + casos_comercial_con_etiquetas_complejas) DESC;
```

### **Error de Consistencia 2: Fechas vs Particionamiento**
**Descripción**: Registros en trimestre incorrecto según su fecha
**Impacto**: Análisis temporales erróneos

```sql
-- DIAGNÓSTICO: Registros en trimestre incorrecto
SELECT 
    'Q1_fuera_rango' as problema,
    COUNT(*) as registros_erroneos,
    MIN(fecha) as fecha_minima_erronea,
    MAX(fecha) as fecha_maxima_erronea
FROM llamadas_Q1 
WHERE STR_TO_DATE(fecha, '%d/%m/%Y') NOT BETWEEN '2025-02-01' AND '2025-03-31'

UNION ALL

SELECT 'Q2_fuera_rango',
       COUNT(*), MIN(fecha), MAX(fecha)
FROM llamadas_Q2
WHERE STR_TO_DATE(fecha, '%d/%m/%Y') NOT BETWEEN '2025-04-01' AND '2025-06-30'

UNION ALL

SELECT 'Q3_fuera_rango',
       COUNT(*), MIN(fecha), MAX(fecha) 
FROM llamadas_Q3
WHERE STR_TO_DATE(fecha, '%d/%m/%Y') NOT BETWEEN '2025-07-01' AND '2025-07-31';
```

---

## 3. Problemas de Integridad Referencial

### **Error de Integridad 1: IDs Duplicados Entre Trimestres**
**Descripción**: Mismo idRe aparece en múltiples trimestres
**Impacto**: Problemas al unificar datos, posible doble conteo

```sql
-- DIAGNÓSTICO: Duplicación de idRe entre trimestres
WITH ids_por_trimestre AS (
    SELECT idRe, 'Q1' as trimestre FROM llamadas_Q1
    UNION ALL
    SELECT idRe, 'Q2' as trimestre FROM llamadas_Q2
    UNION ALL
    SELECT idRe, 'Q3' as trimestre FROM llamadas_Q3
),
duplicados AS (
    SELECT 
        idRe,
        COUNT(*) as apariciones,
        GROUP_CONCAT(trimestre) as trimestres_afectados
    FROM ids_por_trimestre
    GROUP BY idRe
    HAVING COUNT(*) > 1
)
SELECT 
    COUNT(*) as ids_duplicados_total,
    SUM(apariciones) as registros_afectados,
    GROUP_CONCAT(idRe LIMIT 10) as ejemplos_ids_duplicados,
    GROUP_CONCAT(DISTINCT trimestres_afectados) as combinaciones_trimestres
FROM duplicados;
```

### **Error de Integridad 2: Referencias Huérfanas**
**Descripción**: Campos de referencia con valores que no corresponden a entidades válidas
**Impacto**: Imposibilidad de hacer joins, datos incongruentes

```sql
-- DIAGNÓSTICO: Análisis de referencias potencialmente huérfanas
SELECT 
    'cIdentifica_patron_anomalo' as tipo_problema,
    COUNT(*) as casos,
    'Valores que no siguen patrón esperado' as descripcion
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE cIdentifica IS NOT NULL 
  AND cIdentifica != ''
  AND (LENGTH(cIdentifica) < 10 OR cIdentifica NOT REGEXP '^[0-9]+$')

UNION ALL

SELECT 'nidMQ_sin_numero_digitado',
       COUNT(*),
       'nidMQ poblado pero numero_digitado nulo'
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE nidMQ IS NOT NULL 
  AND nidMQ != ''
  AND (numero_digitado IS NULL OR numero_digitado = '')

UNION ALL

SELECT 'id_CTransferencia_invalido',
       COUNT(*),
       'Valores de transferencia que no siguen patrón esperado'
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE id_CTransferencia IS NOT NULL
  AND id_CTransferencia != ''
  AND id_CTransferencia NOT REGEXP '^[0-9]+$';
```

---

## 4. Problemas de Rangos y Formatos

### **Error de Formato 1: Números Telefónicos Inválidos**
**Descripción**: Valores que no corresponden a números telefónicos válidos
**Impacto**: Análisis de usuarios incorrectos

```sql
-- DIAGNÓSTICO: Validación de formato de números telefónicos
SELECT 
    'numero_entrada_formato_invalido' as problema,
    COUNT(*) as casos_problematicos,
    GROUP_CONCAT(DISTINCT numero_entrada LIMIT 10) as ejemplos_invalidos
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE numero_entrada IS NOT NULL
  AND (
    LENGTH(numero_entrada) NOT BETWEEN 7 AND 15
    OR numero_entrada NOT REGEXP '^[0-9]+$'
    OR numero_entrada REGEXP '^0+$'  -- Solo ceros
  )

UNION ALL

SELECT 'numero_digitado_formato_invalido',
       COUNT(*),
       GROUP_CONCAT(DISTINCT numero_digitado LIMIT 10)
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE numero_digitado IS NOT NULL
  AND numero_digitado != ''
  AND (
    LENGTH(numero_digitado) NOT BETWEEN 7 AND 15
    OR numero_digitado NOT REGEXP '^[0-9]+$'
    OR numero_digitado REGEXP '^0+$'
  );
```

### **Error de Formato 2: Fechas Inválidas**
**Descripción**: Fechas que no pueden convertirse o están fuera de rango lógico
**Impacto**: Errores en análisis temporales

```sql
-- DIAGNÓSTICO: Validación de fechas
SELECT 
    'fechas_invalidas' as problema,
    tabla,
    COUNT(*) as casos_problematicos,
    GROUP_CONCAT(DISTINCT fecha LIMIT 10) as ejemplos_fechas_problematicas
FROM (
    SELECT fecha, 'Q1' as tabla FROM llamadas_Q1
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL
       OR STR_TO_DATE(fecha, '%d/%m/%Y') < '2020-01-01'
       OR STR_TO_DATE(fecha, '%d/%m/%Y') > '2030-12-31'
    
    UNION ALL
    
    SELECT fecha, 'Q2' FROM llamadas_Q2
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL
       OR STR_TO_DATE(fecha, '%d/%m/%Y') < '2020-01-01'
       OR STR_TO_DATE(fecha, '%d/%m/%Y') > '2030-12-31'
       
    UNION ALL
    
    SELECT fecha, 'Q3' FROM llamadas_Q3
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL
       OR STR_TO_DATE(fecha, '%d/%m/%Y') < '2020-01-01'
       OR STR_TO_DATE(fecha, '%d/%m/%Y') > '2030-12-31'
) fechas_problematicas
GROUP BY tabla;
```

---

## 5. Problemas de Distribución y Outliers

### **Error de Distribución 1: Valores Extremos**
**Descripción**: Registros con valores que están fuera del rango esperado
**Impacto**: Sesgos en promedios y análisis estadísticos

```sql
-- DIAGNÓSTICO: Detección de outliers
WITH estadisticas_usuario AS (
    SELECT 
        numero_entrada,
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT fecha) as dias_activos,
        COUNT(*) / COUNT(DISTINCT fecha) as interacciones_por_dia,
        COUNT(DISTINCT menu) as menus_diferentes,
        COUNT(DISTINCT id_8T) as zonas_diferentes
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL SELECT * FROM llamadas_Q2
        UNION ALL SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE numero_entrada IS NOT NULL
    GROUP BY numero_entrada
),
percentiles AS (
    SELECT 
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_interacciones) as p95_interacciones,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY interacciones_por_dia) as p95_interacciones_dia,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY menus_diferentes) as p95_menus,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY zonas_diferentes) as p95_zonas
    FROM estadisticas_usuario
)
SELECT 
    'usuarios_outliers_volumen' as tipo_outlier,
    COUNT(*) as cantidad_outliers,
    MIN(total_interacciones) as min_valor_outlier,
    MAX(total_interacciones) as max_valor_outlier,
    GROUP_CONCAT(numero_entrada LIMIT 10) as ejemplos_usuarios
FROM estadisticas_usuario, percentiles
WHERE total_interacciones > p95_interacciones * 2  -- Más del doble del percentil 95

UNION ALL

SELECT 'usuarios_outliers_geograficos',
       COUNT(*), MIN(zonas_diferentes), MAX(zonas_diferentes),
       GROUP_CONCAT(numero_entrada LIMIT 10)
FROM estadisticas_usuario, percentiles  
WHERE zonas_diferentes > p95_zonas * 1.5

UNION ALL

SELECT 'usuarios_outliers_diversidad',
       COUNT(*), MIN(menus_diferentes), MAX(menus_diferentes),
       GROUP_CONCAT(numero_entrada LIMIT 10)
FROM estadisticas_usuario, percentiles
WHERE menus_diferentes > p95_menus * 1.5;
```

---

## 6. Score de Calidad General

### **Métrica Integral de Calidad por Trimestre**

```sql
-- SCORE DE CALIDAD INTEGRAL
SELECT 
    tabla,
    total_registros,
    
    -- Errores críticos
    timestamps_invertidos,
    campos_criticos_nulos,
    fechas_invalidas,
    
    -- Score de calidad (0-100)
    ROUND(
        100 - (
            (timestamps_invertidos * 100.0 / total_registros * 0.3) +
            (campos_criticos_nulos * 100.0 / total_registros * 0.4) + 
            (fechas_invalidas * 100.0 / total_registros * 0.3)
        ), 2
    ) as score_calidad,
    
    -- Clasificación de calidad
    CASE 
        WHEN score_calidad >= 90 THEN 'EXCELENTE'
        WHEN score_calidad >= 75 THEN 'BUENA'
        WHEN score_calidad >= 60 THEN 'REGULAR'
        WHEN score_calidad >= 40 THEN 'MALA'
        ELSE 'CRITICA'
    END as clasificacion_calidad,
    
    -- Registros utilizables para análisis
    total_registros - timestamps_invertidos - campos_criticos_nulos - fechas_invalidas as registros_limpios,
    ROUND((total_registros - timestamps_invertidos - campos_criticos_nulos - fechas_invalidas) * 100.0 / total_registros, 2) as porcentaje_utilizables

FROM (
    SELECT 
        'llamadas_Q1' as tabla,
        COUNT(*) as total_registros,
        SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) as timestamps_invertidos,
        SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) as campos_criticos_nulos,
        SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) as fechas_invalidas,
        100 - (
            (SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3) +
            (SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.4) + 
            (SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3)
        ) as score_calidad
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'llamadas_Q2', COUNT(*),
           SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END),
           SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END),
           100 - (
               (SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3) +
               (SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.4) + 
               (SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3)
           )
    FROM llamadas_Q2
    
    UNION ALL
    
    SELECT 'llamadas_Q3', COUNT(*),
           SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END),
           SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END),
           100 - (
               (SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3) +
               (SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.4) + 
               (SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3)
           )
    FROM llamadas_Q3
) calidad_por_trimestre;
```

---

## 7. Impacto en Reportes

### **Impacto en Reporte de Promedio de Interacciones**

```sql
-- ANÁLISIS DE IMPACTO EN EL REPORTE PRINCIPAL
SELECT 
    'CON_TODOS_LOS_DATOS' as escenario,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    COUNT(*) as total_interacciones, 
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_por_usuario
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas

UNION ALL

SELECT 'SOLO_DATOS_LIMPIOS' as escenario,
       COUNT(DISTINCT numero_entrada),
       COUNT(*),
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2)
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE numero_entrada IS NOT NULL
  AND menu IS NOT NULL
  AND STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL

UNION ALL

SELECT 'DATOS_ULTRA_LIMPIOS' as escenario,
       COUNT(DISTINCT numero_entrada),
       COUNT(*),
       ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2)
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE numero_entrada IS NOT NULL
  AND menu IS NOT NULL
  AND STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL
  AND etiquetas IS NOT NULL
  AND etiquetas != ''
  AND menu NOT IN ('cte_colgo', 'SinOpcion_Cbc');
```

---

## 8. Recomendaciones de Corrección

### **Priorización de Correcciones**

1. **CRÍTICO - Inmediato**:
   - Timestamps invertidos (afectan todos los cálculos temporales)
   - Campos numero_entrada y menu nulos (registros inutilizables)

2. **ALTO - Esta semana**:
   - Fechas fuera de rango de trimestre
   - Inconsistencias menu-opcion-etiquetas más frecuentes

3. **MEDIO - Próximo sprint**:
   - Formatos de números telefónicos
   - Referencias huérfanas
   
4. **BAJO - Mantenimiento**:
   - Outliers extremos
   - Duplicados de idRe entre trimestres

### **Estrategias de Limpieza Sugeridas**

```sql
-- QUERY DE LIMPIEZA RECOMENDADA PARA REPORTES
CREATE VIEW v_datos_limpios_reportes AS
SELECT 
    idRe,
    numero_entrada,
    numero_digitado,
    menu,
    opcion,
    id_CTransferencia,
    fecha,
    division,
    area,
    
    -- Timestamps corregidos
    CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END as hora_inicio_corregida,
    CASE WHEN hora_fin < hora_inicio THEN hora_inicio ELSE hora_fin END as hora_fin_corregida,
    
    id_8T,
    etiquetas,
    cIdentifica,
    fecha_inserta,
    nidMQ,
    
    -- Flags de calidad
    CASE WHEN hora_fin < hora_inicio THEN 'CORREGIDO' ELSE 'ORIGINAL' END as flag_timestamp,
    CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 'SIN_ETIQUETAS' ELSE 'CON_ETIQUETAS' END as flag_procesamiento
    
FROM (
    SELECT *, 'Q1' as trimestre_origen FROM llamadas_Q1
    UNION ALL
    SELECT *, 'Q2' as trimestre_origen FROM llamadas_Q2
    UNION ALL
    SELECT *, 'Q3' as trimestre_origen FROM llamadas_Q3
) todas_llamadas

WHERE numero_entrada IS NOT NULL
  AND numero_entrada != ''
  AND menu IS NOT NULL
  AND menu != ''  
  AND STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL;
```

---

## Conclusión

El análisis revela problemas significativos de calidad que afectan la confiabilidad de los reportes. Se requiere implementar estrategias de limpieza antes de generar análisis definitivos, priorizando la corrección de timestamps invertidos y campos críticos nulos que tienen el mayor impacto en los cálculos de promedio de interacciones.