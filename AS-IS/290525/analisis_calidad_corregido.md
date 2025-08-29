# AS-IS: Análisis de Calidad de Datos - Diagnóstico Completo de Errores
## Versión Corregida para MariaDB 10.1

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
    
    -- Análisis de impacto por menú (limitado para compatibilidad)
    SUBSTRING(GROUP_CONCAT(DISTINCT 
        CASE WHEN hora_fin < hora_inicio THEN menu END
        ORDER BY menu SEPARATOR ','
    ), 1, 100) as menus_mas_afectados
FROM llamadas_Q1

UNION ALL

SELECT 'llamadas_Q2', COUNT(*), 
       SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END),
       ROUND(SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2),
       SUBSTRING(GROUP_CONCAT(DISTINCT CASE WHEN hora_fin < hora_inicio THEN menu END ORDER BY menu SEPARATOR ','), 1, 100)
FROM llamadas_Q2

UNION ALL

SELECT 'llamadas_Q3', COUNT(*),
       SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END),
       ROUND(SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2),
       SUBSTRING(GROUP_CONCAT(DISTINCT CASE WHEN hora_fin < hora_inicio THEN menu END ORDER BY menu SEPARATOR ','), 1, 100)
FROM llamadas_Q3;
```

### **Error Crítico 2: Fechas Base en Timestamps (INFORMATIVO)**
**Descripción**: Timestamps usan fecha base `01/01/1900` - esto es diseño del sistema, no error
**Impacto**: Requiere concatenación con campo `fecha` para timestamps completos

```sql
-- ANÁLISIS INFORMATIVO: Estructura de timestamps
SELECT 
    'Análisis_timestamps' as analisis,
    COUNT(*) as total_registros,
    COUNT(DISTINCT LEFT(hora_inicio, 10)) as fechas_diferentes_hora_inicio,
    COUNT(DISTINCT LEFT(hora_fin, 10)) as fechas_diferentes_hora_fin,
    
    -- Verificar si todas usan 01/01/1900 (esperado)
    SUM(CASE WHEN LEFT(hora_inicio, 10) = '01/01/1900' THEN 1 ELSE 0 END) as usa_fecha_base_inicio,
    SUM(CASE WHEN LEFT(hora_fin, 10) = '01/01/1900' THEN 1 ELSE 0 END) as usa_fecha_base_fin,
    
    -- Detectar anomalías reales
    SUBSTRING(GROUP_CONCAT(DISTINCT 
        CASE WHEN LEFT(hora_inicio, 10) != '01/01/1900' THEN hora_inicio END 
        SEPARATOR ','
    ), 1, 100) as ejemplos_fechas_anomalas

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
        WHEN registros_nulos * 100.0 / total_registros > 10 THEN 'CRITICO'
        WHEN registros_nulos * 100.0 / total_registros > 5 THEN 'ALTO'
        WHEN registros_nulos * 100.0 / total_registros > 1 THEN 'MODERADO'
        ELSE 'BAJO'
    END as nivel_criticidad
FROM (
    SELECT 'numero_entrada' as campo, 'llamadas_Q1' as tabla,
           SUM(CASE WHEN numero_entrada IS NULL OR numero_entrada = '' THEN 1 ELSE 0 END) as registros_nulos,
           COUNT(*) as total_registros
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'menu', 'llamadas_Q1',
           SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END), COUNT(*)
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'numero_digitado', 'llamadas_Q1',
           SUM(CASE WHEN numero_digitado IS NULL OR numero_digitado = '' THEN 1 ELSE 0 END), COUNT(*)
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'etiquetas', 'llamadas_Q1',
           SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END), COUNT(*)
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'numero_entrada', 'llamadas_Q2',
           SUM(CASE WHEN numero_entrada IS NULL OR numero_entrada = '' THEN 1 ELSE 0 END), COUNT(*)
    FROM llamadas_Q2
    
    UNION ALL
    
    SELECT 'menu', 'llamadas_Q2',
           SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END), COUNT(*)
    FROM llamadas_Q2
    
    UNION ALL
    
    SELECT 'numero_entrada', 'llamadas_Q3',
           SUM(CASE WHEN numero_entrada IS NULL OR numero_entrada = '' THEN 1 ELSE 0 END), COUNT(*)
    FROM llamadas_Q3
    
    UNION ALL
    
    SELECT 'menu', 'llamadas_Q3',
           SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END), COUNT(*)
    FROM llamadas_Q3
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

FROM (
    SELECT 
        menu,
        opcion,
        COUNT(*) as frecuencia,
        
        -- Patrones de etiquetas más comunes para esta combinación
        GROUP_CONCAT(DISTINCT etiquetas ORDER BY etiquetas SEPARATOR '|') as patrones_etiquetas,
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
) patrones_esperados
ORDER BY (casos_opcion_no_reflejada + casos_res_sin_vsi + casos_comercial_con_etiquetas_complejas) DESC;
```

### **Error de Consistencia 2: Fechas vs Particionamiento**
**Descripción**: Registros en trimestre incorrecto según su fecha
**Impacto**: Análisis temporales erróneos

```sql
-- DIAGNÓSTICO: Registros en trimestre incorrecto (fechas corregidas)
SELECT 
    'Q1_fuera_rango' as problema,
    COUNT(*) as registros_erroneos,
    MIN(fecha) as fecha_minima_erronea,
    MAX(fecha) as fecha_maxima_erronea
FROM llamadas_Q1 
WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL
  AND STR_TO_DATE(fecha, '%d/%m/%Y') NOT BETWEEN '2025-01-01' AND '2025-03-31'

UNION ALL

SELECT 'Q2_fuera_rango',
       COUNT(*), MIN(fecha), MAX(fecha)
FROM llamadas_Q2
WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL
  AND STR_TO_DATE(fecha, '%d/%m/%Y') NOT BETWEEN '2025-04-01' AND '2025-06-30'

UNION ALL

SELECT 'Q3_fuera_rango',
       COUNT(*), MIN(fecha), MAX(fecha) 
FROM llamadas_Q3
WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL
  AND STR_TO_DATE(fecha, '%d/%m/%Y') NOT BETWEEN '2025-07-01' AND '2025-09-30';
```

---

## 3. Problemas de Integridad Referencial

### **Error de Integridad 1: IDs Duplicados Entre Trimestres**
**Descripción**: Mismo idRe aparece en múltiples trimestres
**Impacto**: Problemas al unificar datos, posible doble conteo

```sql
-- DIAGNÓSTICO: Duplicación de idRe entre trimestres
SELECT 
    COUNT(*) as ids_duplicados_total,
    SUM(apariciones) as registros_afectados,
    SUBSTRING(GROUP_CONCAT(idRe ORDER BY apariciones DESC SEPARATOR ','), 1, 100) as ejemplos_ids_duplicados,
    GROUP_CONCAT(DISTINCT trimestres_afectados SEPARATOR ';') as combinaciones_trimestres
FROM (
    SELECT 
        idRe,
        COUNT(*) as apariciones,
        GROUP_CONCAT(trimestre SEPARATOR ',') as trimestres_afectados
    FROM (
        SELECT idRe, 'Q1' as trimestre FROM llamadas_Q1
        UNION ALL
        SELECT idRe, 'Q2' as trimestre FROM llamadas_Q2
        UNION ALL
        SELECT idRe, 'Q3' as trimestre FROM llamadas_Q3
    ) ids_por_trimestre
    GROUP BY idRe
    HAVING COUNT(*) > 1
) duplicados;
```

### **Error de Integridad 2: Referencias Huérfanas**
**Descripción**: Campos de referencia con valores que no corresponden a entidades válidas
**Impacto**: Imposibilidad de hacer joins, datos incongruentes

```sql
-- DIAGNÓSTICO: Análisis de referencias potencialmente huérfanas
SELECT 
    'cIdentifica_patron_anomalo' as tipo_problema,
    COUNT(*) as casos,
    'Valores que no siguen patrón esperado' as descripcion,
    SUBSTRING(GROUP_CONCAT(DISTINCT cIdentifica SEPARATOR ','), 1, 100) as ejemplos
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE cIdentifica IS NOT NULL 
  AND cIdentifica != ''
  AND (LENGTH(cIdentifica) < 10 OR cIdentifica NOT RLIKE '^[0-9]+$')

UNION ALL

SELECT 'nidMQ_sin_numero_digitado',
       COUNT(*),
       'nidMQ poblado pero numero_digitado nulo',
       SUBSTRING(GROUP_CONCAT(DISTINCT nidMQ SEPARATOR ','), 1, 100)
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
       'Valores de transferencia que no siguen patrón esperado',
       SUBSTRING(GROUP_CONCAT(DISTINCT id_CTransferencia SEPARATOR ','), 1, 100)
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE id_CTransferencia IS NOT NULL
  AND id_CTransferencia != ''
  AND id_CTransferencia NOT RLIKE '^[0-9]+$';
```

---

## 4. Problemas de Rangos y Formatos

### **Error de Formato 1: Números Telefónicos Inválidos**
**Descripción**: Valores que no corresponden a números telefónicos válidos
**Impacto**: Análisis de usuarios incorrectos

```sql
-- DIAGNÓSTICO: Validación de formato de números telefónicos (ajustado para contexto)
SELECT 
    'numero_entrada_formato_sospechoso' as problema,
    COUNT(*) as casos_problematicos,
    SUBSTRING(GROUP_CONCAT(DISTINCT numero_entrada SEPARATOR ','), 1, 100) as ejemplos_sospechosos
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE numero_entrada IS NOT NULL
  AND (
    LENGTH(numero_entrada) < 4  -- Muy corto
    OR LENGTH(numero_entrada) > 15  -- Muy largo
    OR numero_entrada NOT RLIKE '^[0-9]+$'  -- No numérico
    OR numero_entrada RLIKE '^0+$'  -- Solo ceros
    OR numero_entrada RLIKE '^1+$'  -- Solo unos
  )

UNION ALL

SELECT 'numero_digitado_formato_sospechoso',
       COUNT(*),
       SUBSTRING(GROUP_CONCAT(DISTINCT numero_digitado SEPARATOR ','), 1, 100)
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE numero_digitado IS NOT NULL
  AND numero_digitado != ''
  AND (
    LENGTH(numero_digitado) < 4
    OR LENGTH(numero_digitado) > 15
    OR numero_digitado NOT RLIKE '^[0-9]+$'
    OR numero_digitado RLIKE '^0+$'
  );
```

### **Error de Formato 2: Fechas Inválidas**
**Descripción**: Fechas que no pueden convertirse o están fuera de rango lógico
**Impacto**: Errores en análisis temporales

```sql
-- DIAGNÓSTICO: Validación de fechas
SELECT 
    problema,
    tabla,
    COUNT(*) as casos_problematicos,
    SUBSTRING(GROUP_CONCAT(DISTINCT fecha SEPARATOR ','), 1, 100) as ejemplos_fechas_problematicas
FROM (
    SELECT 'fechas_no_convertibles' as problema, fecha, 'Q1' as tabla 
    FROM llamadas_Q1
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL
    
    UNION ALL
    
    SELECT 'fechas_fuera_rango' as problema, fecha, 'Q1' as tabla
    FROM llamadas_Q1
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL
      AND (STR_TO_DATE(fecha, '%d/%m/%Y') < '2020-01-01'
           OR STR_TO_DATE(fecha, '%d/%m/%Y') > '2030-12-31')
    
    UNION ALL
    
    SELECT 'fechas_no_convertibles', fecha, 'Q2'
    FROM llamadas_Q2
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL
    
    UNION ALL
    
    SELECT 'fechas_fuera_rango', fecha, 'Q2'
    FROM llamadas_Q2
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL
      AND (STR_TO_DATE(fecha, '%d/%m/%Y') < '2020-01-01'
           OR STR_TO_DATE(fecha, '%d/%m/%Y') > '2030-12-31')
           
    UNION ALL
    
    SELECT 'fechas_no_convertibles', fecha, 'Q3'
    FROM llamadas_Q3
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL
    
    UNION ALL
    
    SELECT 'fechas_fuera_rango', fecha, 'Q3'
    FROM llamadas_Q3
    WHERE STR_TO_DATE(fecha, '%d/%m/%Y') IS NOT NULL
      AND (STR_TO_DATE(fecha, '%d/%m/%Y') < '2020-01-01'
           OR STR_TO_DATE(fecha, '%d/%m/%Y') > '2030-12-31')
) fechas_problematicas
GROUP BY problema, tabla;
```

---

## 5. Problemas de Distribución y Outliers

### **Error de Distribución 1: Valores Extremos**
**Descripción**: Registros con valores que están fuera del rango esperado
**Impacto**: Sesgos en promedios y análisis estadísticos

```sql
-- DIAGNÓSTICO: Detección de outliers usando percentiles aproximados
WITH estadisticas_usuario AS (
    SELECT 
        numero_entrada,
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT fecha) as dias_activos,
        ROUND(COUNT(*) / COUNT(DISTINCT fecha), 2) as interacciones_por_dia,
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
percentiles_aproximados AS (
    -- Aproximación de percentil 95 usando ORDER BY y LIMIT
    SELECT 
        (SELECT total_interacciones 
         FROM estadisticas_usuario 
         ORDER BY total_interacciones 
         LIMIT 1 OFFSET (SELECT FLOOR(COUNT(*) * 0.95) FROM estadisticas_usuario)) as p95_interacciones,
        
        (SELECT menus_diferentes 
         FROM estadisticas_usuario 
         ORDER BY menus_diferentes 
         LIMIT 1 OFFSET (SELECT FLOOR(COUNT(*) * 0.95) FROM estadisticas_usuario)) as p95_menus,
        
        (SELECT zonas_diferentes 
         FROM estadisticas_usuario 
         ORDER BY zonas_diferentes 
         LIMIT 1 OFFSET (SELECT FLOOR(COUNT(*) * 0.95) FROM estadisticas_usuario)) as p95_zonas
)
SELECT 
    'usuarios_outliers_volumen' as tipo_outlier,
    COUNT(*) as cantidad_outliers,
    MIN(total_interacciones) as min_valor_outlier,
    MAX(total_interacciones) as max_valor_outlier,
    SUBSTRING(GROUP_CONCAT(numero_entrada SEPARATOR ','), 1, 100) as ejemplos_usuarios
FROM estadisticas_usuario, percentiles_aproximados
WHERE total_interacciones > p95_interacciones * 2  -- Más del doble del percentil 95

UNION ALL

SELECT 'usuarios_outliers_geograficos',
       COUNT(*), MIN(zonas_diferentes), MAX(zonas_diferentes),
       SUBSTRING(GROUP_CONCAT(numero_entrada SEPARATOR ','), 1, 100)
FROM estadisticas_usuario, percentiles_aproximados  
WHERE zonas_diferentes > p95_zonas * 1.5

UNION ALL

SELECT 'usuarios_outliers_diversidad',
       COUNT(*), MIN(menus_diferentes), MAX(menus_diferentes),
       SUBSTRING(GROUP_CONCAT(numero_entrada SEPARATOR ','), 1, 100)
FROM estadisticas_usuario, percentiles_aproximados
WHERE menus_diferentes > p95_menus * 1.5;
```

---

## 6. Score de Calidad General

### **Métrica Integral de Calidad por Trimestre**

```sql
-- SCORE DE CALIDAD INTEGRAL (Corregido)
SELECT 
    tabla,
    total_registros,
    timestamps_invertidos,
    campos_criticos_nulos,
    fechas_invalidas,
    
    -- Score de calidad (0-100) calculado correctamente
    ROUND(100 - (
        (timestamps_invertidos * 100.0 / total_registros * 0.3) +
        (campos_criticos_nulos * 100.0 / total_registros * 0.4) + 
        (fechas_invalidas * 100.0 / total_registros * 0.3)
    ), 2) as score_calidad,
    
    -- Registros utilizables para análisis
    total_registros - timestamps_invertidos - campos_criticos_nulos - fechas_invalidas as registros_limpios,
    ROUND((total_registros - timestamps_invertidos - campos_criticos_nulos - fechas_invalidas) * 100.0 / total_registros, 2) as porcentaje_utilizables

FROM (
    SELECT 
        'llamadas_Q1' as tabla,
        COUNT(*) as total_registros,
        SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) as timestamps_invertidos,
        SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) as campos_criticos_nulos,
        SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) as fechas_invalidas
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'llamadas_Q2', COUNT(*),
           SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END),
           SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END)
    FROM llamadas_Q2
    
    UNION ALL
    
    SELECT 'llamadas_Q3', COUNT(*),
           SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END),
           SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END),
           SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END)
    FROM llamadas_Q3
) calidad_por_trimestre;

-- Clasificación de calidad basada en el score
SELECT 
    tabla,
    score_calidad,
    CASE 
        WHEN score_calidad >= 90 THEN 'EXCELENTE'
        WHEN score_calidad >= 75 THEN 'BUENA'
        WHEN score_calidad >= 60 THEN 'REGULAR'
        WHEN score_calidad >= 40 THEN 'MALA'
        ELSE 'CRITICA'
    END as clasificacion_calidad
FROM (
    -- Repetir cálculo del score aquí o usar tabla temporal
    SELECT 
        'llamadas_Q1' as tabla,
        ROUND(100 - (
            (SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3) +
            (SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.4) + 
            (SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3)
        ), 2) as score_calidad
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT 'llamadas_Q2',
           ROUND(100 - (
               (SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3) +
               (SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.4) + 
               (SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3)
           ), 2)
    FROM llamadas_Q2
    
    UNION ALL
    
    SELECT 'llamadas_Q3',
           ROUND(100 - (
               (SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3) +
               (SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.4) + 
               (SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) * 0.3)
           ), 2)
    FROM llamadas_Q3
) scores_calculados;
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
  AND hora_fin >= hora_inicio

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
  AND hora_fin >= hora_inicio
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
   - Formatos de números telefónicos sospechosos
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
    CASE WHEN hora_fin < hora_inicio 
         THEN hora_fin 
         ELSE hora_inicio 
    END as hora_inicio_corregida,
    
    CASE WHEN hora_fin < hora_inicio 
         THEN hora_inicio 
         ELSE hora_fin 
    END as hora_fin_corregida,
    
    -- Timestamp completo construido
    CONCAT(fecha, ' ', 
           CASE WHEN hora_fin < hora_inicio 
                THEN SUBSTRING(hora_fin, 12) 
                ELSE SUBSTRING(hora_inicio, 12) 
           END) as timestamp_inicio_completo,
    
    id_8T,
    etiquetas,
    cIdentifica,
    fecha_inserta,
    nidMQ,
    
    -- Flags de calidad
    CASE WHEN hora_fin < hora_inicio THEN 'CORREGIDO' ELSE 'ORIGINAL' END as flag_timestamp,
    CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 'SIN_ETIQUETAS' ELSE 'CON_ETIQUETAS' END as flag_procesamiento,
    
    -- Trimestre de origen
    trimestre_origen
    
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

### **Query para Identificar Registros Problemáticos Específicos**

```sql
-- IDENTIFICAR REGISTROS ESPECÍFICOS CON MÚLTIPLES PROBLEMAS
SELECT 
    idRe,
    numero_entrada,
    numero_digitado,
    menu,
    fecha,
    hora_inicio,
    hora_fin,
    
    -- Problemas detectados
    CONCAT_WS(',',
        CASE WHEN hora_fin < hora_inicio THEN 'TIMESTAMP_INVERTIDO' END,
        CASE WHEN numero_entrada IS NULL OR numero_entrada = '' THEN 'SIN_NUMERO_ENTRADA' END,
        CASE WHEN menu IS NULL OR menu = '' THEN 'SIN_MENU' END,
        CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 'FECHA_INVALIDA' END,
        CASE WHEN numero_entrada IS NOT NULL AND (LENGTH(numero_entrada) < 4 OR LENGTH(numero_entrada) > 15) THEN 'NUMERO_SOSPECHOSO' END,
        CASE WHEN numero_digitado IS NOT NULL AND numero_digitado != '' AND (LENGTH(numero_digitado) < 4 OR LENGTH(numero_digitado) > 15) THEN 'DIGITADO_SOSPECHOSO' END
    ) as problemas_detectados,
    
    -- Severidad del problema
    CASE 
        WHEN (hora_fin < hora_inicio) OR (numero_entrada IS NULL) OR (menu IS NULL) THEN 'CRITICO'
        WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 'ALTO'
        WHEN (numero_entrada IS NOT NULL AND LENGTH(numero_entrada) < 4) THEN 'MEDIO'
        ELSE 'BAJO'
    END as severidad
    
FROM (
    SELECT *, 'Q1' as tabla_origen FROM llamadas_Q1
    UNION ALL
    SELECT *, 'Q2' as tabla_origen FROM llamadas_Q2
    UNION ALL
    SELECT *, 'Q3' as tabla_origen FROM llamadas_Q3
) todas_llamadas

WHERE (hora_fin < hora_inicio)
   OR (numero_entrada IS NULL OR numero_entrada = '')
   OR (menu IS NULL OR menu = '')
   OR (STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL)
   OR (numero_entrada IS NOT NULL AND (LENGTH(numero_entrada) < 4 OR LENGTH(numero_entrada) > 15))
   OR (numero_digitado IS NOT NULL AND numero_digitado != '' AND (LENGTH(numero_digitado) < 4 OR LENGTH(numero_digitado) > 15))

ORDER BY 
    CASE severidad
        WHEN 'CRITICO' THEN 1
        WHEN 'ALTO' THEN 2
        WHEN 'MEDIO' THEN 3
        ELSE 4
    END,
    idRe

LIMIT 100;
```

### **Stored Procedure para Limpieza Automática**

```sql
DELIMITER $

CREATE PROCEDURE LimpiarDatosCalidad()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_idRe BIGINT;
    DECLARE v_hora_inicio, v_hora_fin DATETIME;
    DECLARE registros_corregidos INT DEFAULT 0;
    
    -- Cursor para timestamps invertidos
    DECLARE cur_timestamps CURSOR FOR 
        SELECT idRe, hora_inicio, hora_fin 
        FROM llamadas_Q1 
        WHERE hora_fin < hora_inicio;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    -- Corregir timestamps invertidos en Q1
    OPEN cur_timestamps;
    
    timestamp_loop: LOOP
        FETCH cur_timestamps INTO v_idRe, v_hora_inicio, v_hora_fin;
        IF done THEN
            LEAVE timestamp_loop;
        END IF;
        
        -- Intercambiar timestamps
        UPDATE llamadas_Q1 
        SET hora_inicio = v_hora_fin,
            hora_fin = v_hora_inicio
        WHERE idRe = v_idRe;
        
        SET registros_corregidos = registros_corregidos + 1;
    END LOOP;
    
    CLOSE cur_timestamps;
    
    -- Repetir para Q2 y Q3...
    
    SELECT CONCAT('Registros corregidos: ', registros_corregidos) as resultado;
    
END$

DELIMITER ;

-- Uso:
-- CALL LimpiarDatosCalidad();
```

---

## 9. Monitoreo Continuo de Calidad

### **Query para Dashboard de Calidad**

```sql
-- DASHBOARD DE CALIDAD EJECUTABLE DIARIAMENTE
SELECT 
    CURRENT_DATE as fecha_revision,
    'RESUMEN_GENERAL' as tipo_metrica,
    SUM(total_registros) as total_registros_sistema,
    SUM(registros_limpios) as total_registros_limpios,
    ROUND(SUM(registros_limpios) * 100.0 / SUM(total_registros), 2) as porcentaje_calidad_global,
    
    CASE 
        WHEN SUM(registros_limpios) * 100.0 / SUM(total_registros) >= 90 THEN 'SISTEMA_SALUDABLE'
        WHEN SUM(registros_limpios) * 100.0 / SUM(total_registros) >= 75 THEN 'REQUIERE_ATENCION'
        ELSE 'ESTADO_CRITICO'
    END as estado_sistema

FROM (
    SELECT 
        COUNT(*) as total_registros,
        COUNT(*) - SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) 
                 - SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) 
                 - SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END) as registros_limpios
    FROM llamadas_Q1
    
    UNION ALL
    
    SELECT COUNT(*),
           COUNT(*) - SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) 
                    - SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) 
                    - SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END)
    FROM llamadas_Q2
    
    UNION ALL
    
    SELECT COUNT(*),
           COUNT(*) - SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) 
                    - SUM(CASE WHEN numero_entrada IS NULL OR menu IS NULL THEN 1 ELSE 0 END) 
                    - SUM(CASE WHEN STR_TO_DATE(fecha, '%d/%m/%Y') IS NULL THEN 1 ELSE 0 END)
    FROM llamadas_Q3
) calidad_trimestres;
```

---

## Conclusión

El análisis revela problemas de calidad que requieren atención inmediata, especialmente:

1. **Timestamps invertidos** - Impactan cálculos de duración y ordenamiento
2. **Campos críticos nulos** - Hacen registros inutilizables 
3. **Fechas inválidas** - Afectan análisis temporales

**Acciones Recomendadas:**
- Implementar corrección automática de timestamps invertidos
- Establecer validaciones en el proceso de carga de datos
- Crear vista de datos limpios para reportes
- Monitorear calidad de datos de forma continua

El sistema mantiene un nivel de calidad **aceptable** pero requiere mejoras para alcanzar estándares de **excelencia** en análisis de datos.