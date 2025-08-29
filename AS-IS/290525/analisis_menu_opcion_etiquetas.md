# Análisis Completo: Relaciones Menu, Opción y Etiquetas
## MariaDB 10.1 - Técnicas de Normalización y Análisis de Datos Separados por Coma

---

## **1. Técnicas para Manejo de Etiquetas Separadas por Coma**

### **Opción A: Normalización a Filas (Recomendado)**
Convertir `etiquetas` de "2L,ZMB,VSI" a filas individuales usando técnicas compatibles con MariaDB 10.1:

```sql
-- TÉCNICA 1: SUBSTRING_INDEX con tabla de números
-- Crear tabla auxiliar de números (una sola vez)
CREATE TEMPORARY TABLE numeros AS
SELECT 1 as n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10;

-- Normalizar etiquetas a filas
SELECT 
    idRe,
    numero_entrada,
    menu,
    opcion,
    TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(etiquetas, ',', n), ',', -1)) as etiqueta_individual
FROM (
    SELECT * FROM llamadas_Q1 
    UNION ALL SELECT * FROM llamadas_Q2 
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
CROSS JOIN numeros
WHERE n <= (LENGTH(etiquetas) - LENGTH(REPLACE(etiquetas, ',', '')) + 1)
  AND etiquetas IS NOT NULL 
  AND etiquetas != '';
```

### **Opción B: Columnas Binarias (Para análisis específico)**
Crear columnas booleanas para etiquetas más comunes:

```sql
-- ANÁLISIS: Identificar etiquetas más frecuentes primero
SELECT 
    etiqueta,
    COUNT(*) as frecuencia,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1 WHERE etiquetas IS NOT NULL), 2) as porcentaje
FROM (
    SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(etiquetas, ',', n), ',', -1)) as etiqueta
    FROM llamadas_Q1
    CROSS JOIN (SELECT 1 as n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) nums
    WHERE n <= (LENGTH(etiquetas) - LENGTH(REPLACE(etiquetas, ',', '')) + 1)
      AND etiquetas IS NOT NULL
) etiquetas_normalizadas
GROUP BY etiqueta
ORDER BY frecuencia DESC
LIMIT 20;

-- Crear vista con columnas binarias para top etiquetas
CREATE VIEW v_etiquetas_binarias AS
SELECT 
    idRe, numero_entrada, menu, opcion, fecha,
    etiquetas,
    
    -- Columnas binarias para etiquetas principales
    CASE WHEN etiquetas LIKE '%ZMB%' THEN 1 ELSE 0 END as tiene_ZMB,
    CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END as tiene_VSI,
    CASE WHEN etiquetas LIKE '%2L%' THEN 1 ELSE 0 END as tiene_2L,
    CASE WHEN etiquetas LIKE '%1L%' THEN 1 ELSE 0 END as tiene_1L,
    CASE WHEN etiquetas LIKE '%WTS%' THEN 1 ELSE 0 END as tiene_WTS,
    CASE WHEN etiquetas LIKE '%TELCO%' THEN 1 ELSE 0 END as tiene_TELCO,
    CASE WHEN etiquetas LIKE '%MGC%' THEN 1 ELSE 0 END as tiene_MGC,
    CASE WHEN etiquetas LIKE '%NOBOT%' THEN 1 ELSE 0 END as tiene_NOBOT,
    CASE WHEN etiquetas LIKE '%DEFAULT%' THEN 1 ELSE 0 END as tiene_DEFAULT
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas;
```

---

## **2. Preguntas de Análisis por Combinación**

### **2.1 Solo MENU**
```sql
-- ¿Cuáles son los menús más utilizados?
SELECT 
    menu,
    COUNT(*) as total_usos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_por_usuario,
    COUNT(DISTINCT fecha) as dias_activos,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje_total
FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu
ORDER BY total_usos DESC
LIMIT 15;

-- ¿Qué menús tienen mayor tasa de abandono (sin etiquetas)?
SELECT 
    menu,
    COUNT(*) as total,
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as sin_etiquetas,
    ROUND(SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_abandono
FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu
HAVING COUNT(*) >= 10
ORDER BY tasa_abandono DESC;
```

### **2.2 Solo OPCIÓN**
```sql
-- ¿Cuáles son las opciones más seleccionadas?
SELECT 
    opcion,
    COUNT(*) as frecuencia,
    COUNT(DISTINCT menu) as menus_diferentes,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 10) as menus_asociados
FROM llamadas_Q1
WHERE opcion IS NOT NULL AND opcion != ''
GROUP BY opcion
ORDER BY frecuencia DESC;

-- ¿Qué opciones generan más transferencias exitosas?
SELECT 
    opcion,
    COUNT(*) as total,
    SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, '') THEN 1 ELSE 0 END) as transferencias,
    ROUND(SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, '') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_transferencia
FROM llamadas_Q1
WHERE opcion IS NOT NULL
GROUP BY opcion
HAVING COUNT(*) >= 5
ORDER BY tasa_transferencia DESC;
```

### **2.3 Solo ETIQUETAS (Usando normalización)**
```sql
-- ¿Cuáles son las etiquetas más comunes y su significado operativo?
WITH etiquetas_individuales AS (
    SELECT 
        TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(etiquetas, ',', n), ',', -1)) as etiqueta,
        COUNT(*) as freq_individual
    FROM llamadas_Q1
    CROSS JOIN (SELECT 1 as n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) nums
    WHERE n <= (LENGTH(etiquetas) - LENGTH(REPLACE(etiquetas, ',', '')) + 1)
      AND etiquetas IS NOT NULL
    GROUP BY etiqueta
)
SELECT 
    etiqueta,
    freq_individual,
    CASE 
        WHEN etiqueta LIKE '%VSI%' THEN 'Validación/Verificación'
        WHEN etiqueta LIKE '%ZMB%' THEN 'Zona/Región'
        WHEN etiqueta LIKE '%TELCO%' THEN 'Telecomunicaciones'
        WHEN etiqueta LIKE '%WTS%' THEN 'Sistema Técnico'
        WHEN etiqueta LIKE '%2L%' OR etiqueta LIKE '%1L%' THEN 'Línea/Nivel'
        WHEN etiqueta LIKE '%NOBOT%' THEN 'Sin Robot/Manual'
        ELSE 'Otra categoría'
    END as categoria_inferida
FROM etiquetas_individuales
ORDER BY freq_individual DESC
LIMIT 20;
```

### **2.4 MENU + OPCIÓN**
```sql
-- ¿Cuáles son las combinaciones menu-opción más exitosas?
SELECT 
    menu,
    opcion,
    COUNT(*) as frecuencia,
    
    -- Análisis de completitud
    SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) as con_etiquetas,
    ROUND(SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_completitud,
    
    -- Análisis de transferencias
    SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, '') THEN 1 ELSE 0 END) as transferencias,
    ROUND(SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, '') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_transferencia,
    
    -- Tiempo promedio (aproximado)
    AVG(TIME_TO_SEC(TIMEDIFF(
        STR_TO_DATE(SUBSTRING(hora_fin, 12), '%H:%i:%s'),
        STR_TO_DATE(SUBSTRING(hora_inicio, 12), '%H:%i:%s')
    ))) as segundos_promedio
    
FROM llamadas_Q1
WHERE menu IS NOT NULL AND opcion IS NOT NULL
GROUP BY menu, opcion
HAVING frecuencia >= 5
ORDER BY frecuencia DESC
LIMIT 20;
```

### **2.5 MENU + ETIQUETAS**
```sql
-- ¿Qué menús generan patrones específicos de etiquetas?
SELECT 
    menu,
    COUNT(*) as total_usos,
    COUNT(DISTINCT etiquetas) as patrones_diferentes,
    
    -- Etiquetas más comunes por menú
    SUBSTRING(GROUP_CONCAT(DISTINCT etiquetas ORDER BY etiquetas SEPARATOR ' | '), 1, 200) as patrones_etiquetas,
    
    -- Análisis de consistencia
    CASE 
        WHEN menu LIKE 'RES-%' AND SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) > COUNT(*) * 0.7 
        THEN 'CONSISTENTE_RES'
        WHEN menu LIKE 'comercial_%' AND SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) > COUNT(*) * 0.8
        THEN 'CONSISTENTE_COMERCIAL'
        WHEN COUNT(DISTINCT etiquetas) = 1
        THEN 'PATRON_UNICO'
        WHEN COUNT(DISTINCT etiquetas) > COUNT(*) * 0.8
        THEN 'ALTAMENTE_VARIABLE'
        ELSE 'PATRON_MODERADO'
    END as tipo_patron
    
FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu
HAVING total_usos >= 10
ORDER BY total_usos DESC;
```

### **2.6 OPCIÓN + ETIQUETAS**
```sql
-- ¿Las opciones se reflejan correctamente en las etiquetas?
SELECT 
    opcion,
    COUNT(*) as total,
    
    -- ¿La opción aparece en las etiquetas?
    SUM(CASE WHEN etiquetas LIKE CONCAT('%', opcion, '%') THEN 1 ELSE 0 END) as opcion_en_etiquetas,
    ROUND(SUM(CASE WHEN etiquetas LIKE CONCAT('%', opcion, '%') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as porcentaje_reflejo,
    
    -- Patrones de etiquetas por opción
    GROUP_CONCAT(DISTINCT LEFT(etiquetas, 50) ORDER BY etiquetas LIMIT 5) as ejemplos_etiquetas,
    
    -- Consistencia de procesamiento
    CASE 
        WHEN opcion IN ('DEFAULT', '1', '2', '21') AND SUM(CASE WHEN etiquetas LIKE CONCAT('%', opcion, '%') THEN 1 ELSE 0 END) < COUNT(*) * 0.1
        THEN 'OPCION_GENERICA'
        WHEN SUM(CASE WHEN etiquetas LIKE CONCAT('%', opcion, '%') THEN 1 ELSE 0 END) > COUNT(*) * 0.7
        THEN 'ALTA_CONSISTENCIA'
        WHEN SUM(CASE WHEN etiquetas LIKE CONCAT('%', opcion, '%') THEN 1 ELSE 0 END) > COUNT(*) * 0.3
        THEN 'CONSISTENCIA_MEDIA'
        ELSE 'BAJA_CONSISTENCIA'
    END as nivel_consistencia
    
FROM llamadas_Q1
WHERE opcion IS NOT NULL AND opcion != ''
GROUP BY opcion
HAVING total >= 5
ORDER BY porcentaje_reflejo DESC;
```

### **2.7 MENU + OPCIÓN + ETIQUETAS (Análisis Integral)**
```sql
-- ¿Cuáles son los flujos de interacción más completos y exitosos?
SELECT 
    CONCAT(menu, ' → ', COALESCE(opcion, 'SIN_OPCION')) as flujo,
    COUNT(*) as frecuencia,
    
    -- Análisis de etiquetas
    COUNT(DISTINCT etiquetas) as variabilidad_etiquetas,
    AVG(LENGTH(etiquetas) - LENGTH(REPLACE(etiquetas, ',', '')) + 1) as promedio_etiquetas_por_interaccion,
    
    -- Análisis de resultados
    SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, '') THEN 1 ELSE 0 END) as transferencias_exitosas,
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as con_validacion,
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as sin_procesamiento,
    
    -- Métricas de calidad del flujo
    ROUND(SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_completitud,
    ROUND(SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, '') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_transferencia,
    
    -- Clasificación del flujo
    CASE 
        WHEN SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) > COUNT(*) * 0.9
             AND SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, '') THEN 1 ELSE 0 END) > COUNT(*) * 0.3
        THEN 'FLUJO_OPTIMO'
        WHEN SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) > COUNT(*) * 0.5
        THEN 'FLUJO_PROBLEMATICO'
        WHEN menu LIKE '%cte_colgo%' OR menu LIKE '%SinOpcion%'
        THEN 'FLUJO_ABANDONO'
        ELSE 'FLUJO_NORMAL'
    END as clasificacion_flujo
    
FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY CONCAT(menu, ' → ', COALESCE(opcion, 'SIN_OPCION'))
HAVING frecuencia >= 10
ORDER BY 
    CASE clasificacion_flujo
        WHEN 'FLUJO_OPTIMO' THEN 1
        WHEN 'FLUJO_NORMAL' THEN 2
        WHEN 'FLUJO_PROBLEMATICO' THEN 3
        WHEN 'FLUJO_ABANDONO' THEN 4
    END,
    frecuencia DESC
LIMIT 25;
```

---

## **3. Análisis de Patrones y Reglas de Negocio**

### **3.1 Detección de Anomalías en Combinaciones**
```sql
-- ¿Qué combinaciones rompen las reglas esperadas?
SELECT 
    'REGLA_VIOLADA' as tipo_anomalia,
    menu,
    opcion,
    etiquetas,
    COUNT(*) as frecuencia_anomalia,
    'RES sin VSI' as descripcion
FROM llamadas_Q1
WHERE menu LIKE 'RES-%' 
  AND (etiquetas IS NULL OR etiquetas NOT LIKE '%VSI%')
  AND etiquetas IS NOT NULL
GROUP BY menu, opcion, etiquetas

UNION ALL

SELECT 'OPCION_NO_REFLEJADA',
       menu, opcion, etiquetas, COUNT(*),
       'Opción no aparece en etiquetas'
FROM llamadas_Q1
WHERE opcion IS NOT NULL 
  AND opcion NOT IN ('DEFAULT', '1', '21', '2')
  AND LENGTH(opcion) > 2
  AND (etiquetas IS NULL OR etiquetas NOT LIKE CONCAT('%', opcion, '%'))
GROUP BY menu, opcion, etiquetas

UNION ALL

SELECT 'COMERCIAL_CON_ETIQUETAS_COMPLEJAS',
       menu, opcion, etiquetas, COUNT(*),
       'Menu comercial con etiquetas inesperadas'
FROM llamadas_Q1
WHERE menu LIKE 'comercial_%'
  AND etiquetas IS NOT NULL 
  AND LENGTH(etiquetas) > 10
  AND etiquetas NOT LIKE '%DEFAULT%'
GROUP BY menu, opcion, etiquetas

ORDER BY frecuencia_anomalia DESC
LIMIT 20;
```

### **3.2 Análisis de Evolución Temporal**
```sql
-- ¿Cómo evolucionan los patrones menu-opcion-etiquetas por trimestre?
SELECT 
    trimestre,
    COUNT(DISTINCT CONCAT(menu, '|', COALESCE(opcion, 'NULL'))) as combinaciones_menu_opcion,
    COUNT(DISTINCT etiquetas) as patrones_etiquetas_unicos,
    
    -- Consistencia temporal
    SUM(CASE WHEN menu LIKE 'RES-%' AND etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as res_con_vsi,
    SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) as total_res,
    ROUND(SUM(CASE WHEN menu LIKE 'RES-%' AND etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / 
          NULLIF(SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END), 0), 2) as consistencia_res_vsi,
    
    -- Nuevos patrones por trimestre
    COUNT(DISTINCT CASE WHEN etiquetas IS NOT NULL THEN CONCAT(menu, ':', etiquetas) END) as patrones_completos
    
FROM (
    SELECT *, 'Q1' as trimestre FROM llamadas_Q1
    UNION ALL
    SELECT *, 'Q2' as trimestre FROM llamadas_Q2
    UNION ALL
    SELECT *, 'Q3' as trimestre FROM llamadas_Q3
) datos_temporales
WHERE menu IS NOT NULL
GROUP BY trimestre
ORDER BY trimestre;
```

---

## **4. Consultas para Crear Dashboards**

### **4.1 Dashboard de Eficiencia de Menús**
```sql
-- Métrica integral de rendimiento por menú
SELECT 
    menu,
    COUNT(*) as volumen_total,
    COUNT(DISTINCT numero_entrada) as usuarios_alcanzados,
    
    -- KPIs de eficiencia
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as interacciones_por_usuario,
    ROUND(SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_procesamiento,
    ROUND(SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, '') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_transferencia,
    
    -- Clasificación de rendimiento
    CASE 
        WHEN SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 90
             AND COUNT(*) >= 100
        THEN 'ALTO_RENDIMIENTO'
        WHEN SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 50
        THEN 'RENDIMIENTO_CRITICO'
        ELSE 'RENDIMIENTO_MEDIO'
    END as categoria_rendimiento,
    
    -- Top 3 opciones más usadas
    (SELECT GROUP_CONCAT(opcion ORDER BY cnt DESC LIMIT 3) 
     FROM (SELECT opcion, COUNT(*) as cnt 
           FROM llamadas_Q1 sub 
           WHERE sub.menu = llamadas_Q1.menu AND opcion IS NOT NULL 
           GROUP BY opcion 
           ORDER BY cnt DESC LIMIT 3) top_ops) as top_opciones

FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu
HAVING volumen_total >= 10
ORDER BY 
    CASE categoria_rendimiento
        WHEN 'ALTO_RENDIMIENTO' THEN 1
        WHEN 'RENDIMIENTO_MEDIO' THEN 2
        WHEN 'RENDIMIENTO_CRITICO' THEN 3
    END,
    volumen_total DESC;
```

### **4.2 Stored Procedure para Análisis Dinámico**
```sql
DELIMITER $$

CREATE PROCEDURE AnalisisMenuOpcionEtiquetas(
    IN p_menu VARCHAR(100) DEFAULT NULL,
    IN p_opcion VARCHAR(50) DEFAULT NULL,
    IN p_etiqueta_filtro VARCHAR(100) DEFAULT NULL,
    IN p_limite INT DEFAULT 20
)
BEGIN
    DECLARE sql_query TEXT;
    
    -- Construcción dinámica del query
    SET sql_query = 'SELECT menu, opcion, etiquetas, COUNT(*) as frecuencia,';
    SET sql_query = CONCAT(sql_query, ' ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje');
    SET sql_query = CONCAT(sql_query, ' FROM llamadas_Q1 WHERE 1=1');
    
    IF p_menu IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' AND menu = ''', p_menu, '''');
    END IF;
    
    IF p_opcion IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' AND opcion = ''', p_opcion, '''');
    END IF;
    
    IF p_etiqueta_filtro IS NOT NULL THEN
        SET sql_query = CONCAT(sql_query, ' AND etiquetas LIKE ''%', p_etiqueta_filtro, '%''');
    END IF;
    
    SET sql_query = CONCAT(sql_query, ' GROUP BY menu, opcion, etiquetas');
    SET sql_query = CONCAT(sql_query, ' ORDER BY frecuencia DESC LIMIT ', p_limite);
    
    SET @sql = sql_query;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- Ejemplos de uso:
-- CALL AnalisisMenuOpcionEtiquetas('RES-ContratacionIfm_2024', NULL, 'VSI', 10);
-- CALL AnalisisMenuOpcionEtiquetas(NULL, 'DEFAULT', NULL, 15);
-- CALL AnalisisMenuOpcionEtiquetas(NULL, NULL, 'ZMB', 20);
```

---

## **5. Preguntas Clave que Este Análisis Responde**

### **Operacionales:**
1. **¿Cuáles son los menús más eficientes?** - Ratio transferencias exitosas vs abandonos
2. **¿Qué opciones generan más confusión?** - Alta variabilidad en etiquetas resultantes
3. **¿Los usuarios completan los flujos diseñados?** - Consistencia menu→opcion→etiquetas

### **Técnicas:**
4. **¿El sistema procesa correctamente las interacciones?** - Presencia y consistencia de etiquetas
5. **¿Hay patrones que indican errores del sistema?** - Anomalías en combinaciones esperadas
6. **¿Las validaciones (VSI) se ejecutan cuando deberían?** - Reglas de negocio cumplidas

### **De Negocio:**
7. **¿Qué rutas de navegación son más exitosas?** - Análisis de flujos completos
8. **¿Los cambios de trimestre a trimestre mejoran la experiencia?** - Evolución temporal
9. **¿Dónde están las oportunidades de optimización?** - Identificación de cuellos de botella

### **De Calidad:**
10. **¿Los datos son consistentes entre menu, opción y etiquetas?** - Detección de inconsistencias
11. **¿Hay valores faltantes que afecten el análisis?** - Completitud de datos
12. **¿Las etiquetas reflejan realmente lo que pasó en la interacción?** - Validación de metadatos

Este análisis proporciona una visión integral del comportamiento del sistema IVR/menu telefónico y la calidad de los datos generados.