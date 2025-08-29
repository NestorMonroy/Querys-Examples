# Análisis Real: Menu-Opción-Etiquetas
## Basado en Patrones Identificados en los Datos Reales - MariaDB 10.1

---

## **Observaciones de los Datos Reales**

### **Patrones Identificados en la Muestra:**
- **Etiquetas vacías frecuentes**: ~40% de registros sin etiquetas
- **Etiquetas terminan en coma**: "2L,ZMB,VSI,NVS," - necesita limpieza
- **Menús NULL con opciones válidas**: Inconsistencias estructurales
- **Números iguales (sin transferencia)**: 2185424078 → 2185424078
- **Campos de tiempo con fecha base**: 01/01/1900 + hora real

---

## **1. Limpieza y Normalización de Etiquetas Reales**

### **Función de Limpieza para Etiquetas**
```sql
-- Limpiar etiquetas reales (quitar comas finales, espacios)
CREATE VIEW v_etiquetas_limpias AS
SELECT 
    idRe, numero_entrada, menu, opcion, fecha,
    CASE 
        WHEN etiquetas IS NULL OR etiquetas = '' THEN NULL
        ELSE TRIM(TRAILING ',' FROM TRIM(etiquetas))
    END as etiquetas_clean
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas;

-- Dividir etiquetas limpias en filas individuales
CREATE TEMPORARY TABLE numeros_hasta_10 AS
SELECT 1 as n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10;

SELECT 
    idRe,
    numero_entrada,
    menu,
    opcion,
    fecha,
    TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(etiquetas_clean, ',', n), ',', -1)) as etiqueta_individual,
    n as posicion_etiqueta
FROM v_etiquetas_limpias
CROSS JOIN numeros_hasta_10
WHERE etiquetas_clean IS NOT NULL
  AND n <= (LENGTH(etiquetas_clean) - LENGTH(REPLACE(etiquetas_clean, ',', '')) + 1)
  AND TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(etiquetas_clean, ',', n), ',', -1)) != '';
```

---

## **2. Análisis por Componente Individual**

### **2.1 Solo MENU - Patrones Reales Observados**
```sql
-- Análisis basado en patrones reales identificados
SELECT 
    CASE 
        WHEN menu IS NULL OR menu = '' THEN 'MENU_FALTANTE'
        WHEN menu LIKE 'RES-%' THEN 'TIPO_RES'
        WHEN menu LIKE 'comercial_%' THEN 'TIPO_COMERCIAL'  
        WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 'ABANDONO_SISTEMA'
        WHEN menu = 'Numero tel' THEN 'CAPTURA_NUMERO'
        WHEN menu LIKE '%Desborde%' THEN 'DESBORDE'
        WHEN menu LIKE 'NOTMX-%' THEN 'NO_MEXICO'
        WHEN menu = 'SDO' THEN 'SALDO'
        WHEN menu LIKE 'PG_%' OR menu LIKE 'ZMB' THEN 'CODIGOS_ESPECIALES'
        ELSE 'OTROS_MENUS'
    END as categoria_menu,
    
    COUNT(*) as total_registros,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- Análisis de completitud real
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as sin_etiquetas,
    ROUND(SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as porcentaje_sin_etiquetas,
    
    -- Transferencias reales
    SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) as con_transferencias,
    ROUND(SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_transferencia,
    
    -- Ejemplos reales de menús por categoría
    SUBSTRING(GROUP_CONCAT(DISTINCT menu ORDER BY menu SEPARATOR ', '), 1, 100) as ejemplos_menus
    
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
GROUP BY categoria_menu
ORDER BY total_registros DESC;
```

### **2.2 Solo OPCION - Valores Reales**
```sql
-- Análisis de opciones basado en datos reales
SELECT 
    CASE 
        WHEN opcion IS NULL OR opcion = '' THEN 'OPCION_FALTANTE'
        WHEN opcion = 'DEFAULT' THEN 'DEFAULT'
        WHEN opcion IN ('1', '2', '5', '11', '21') THEN 'OPCION_NUMERICA'
        WHEN opcion IN ('2L', '1L', 'ML') THEN 'TIPO_LINEA'
        WHEN LENGTH(opcion) > 5 THEN 'OPCION_COMPLEJA'
        ELSE 'OPCION_ESPECIFICA'
    END as tipo_opcion,
    
    COUNT(*) as frecuencia,
    COUNT(DISTINCT menu) as menus_asociados,
    
    -- Análisis de efectividad por tipo de opción
    SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) as con_resultado,
    ROUND(SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_efectividad,
    
    -- Ejemplos reales
    SUBSTRING(GROUP_CONCAT(DISTINCT opcion ORDER BY opcion SEPARATOR ', '), 1, 100) as valores_opcion_reales
    
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
GROUP BY tipo_opcion
ORDER BY frecuencia DESC;
```

### **2.3 Solo ETIQUETAS - Patrones Identificados**
```sql
-- Análisis de etiquetas individuales basado en datos reales
WITH etiquetas_individuales AS (
    SELECT 
        TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(
            TRIM(TRAILING ',' FROM TRIM(etiquetas)), ',', n), ',', -1)
        ) as etiqueta
    FROM (
        SELECT * FROM llamadas_Q1 WHERE etiquetas IS NOT NULL AND etiquetas != ''
        UNION ALL SELECT * FROM llamadas_Q2 WHERE etiquetas IS NOT NULL AND etiquetas != ''
        UNION ALL SELECT * FROM llamadas_Q3 WHERE etiquetas IS NOT NULL AND etiquetas != ''
    ) todas_llamadas
    CROSS JOIN (SELECT 1 as n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) nums
    WHERE n <= (LENGTH(TRIM(TRAILING ',' FROM TRIM(etiquetas))) - LENGTH(REPLACE(TRIM(TRAILING ',' FROM TRIM(etiquetas)), ',', '')) + 1)
      AND TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(TRAILING ',' FROM TRIM(etiquetas)), ',', n), ',', -1)) != ''
)
SELECT 
    etiqueta,
    COUNT(*) as frecuencia,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM etiquetas_individuales), 2) as porcentaje,
    
    -- Clasificación funcional basada en observaciones reales
    CASE 
        WHEN etiqueta = 'ZMB' THEN 'ZONA_METROPOLITANA'
        WHEN etiqueta IN ('VSI', 'DG', 'WTS') THEN 'VALIDACION_TECNICA'
        WHEN etiqueta IN ('2L', '1L', 'ML') THEN 'TIPO_LINEA'
        WHEN etiqueta LIKE 'RES_%' OR etiqueta LIKE 'TELCO%' THEN 'RESULTADO_OPERACION'
        WHEN etiqueta LIKE 'SEG_%' OR etiqueta LIKE 'PR_%' THEN 'SEGMENTO_CLIENTE'
        WHEN etiqueta LIKE 'IN25%' OR etiqueta LIKE 'VALS%' THEN 'IDENTIFICADOR_SISTEMA'
        WHEN etiqueta = 'NOBOT' THEN 'SIN_ROBOT'
        WHEN etiqueta LIKE '%_MA%' OR etiqueta LIKE '%_AB_%' THEN 'CODIGO_PROCESO'
        ELSE 'OTRO_CODIGO'
    END as categoria_funcional
    
FROM etiquetas_individuales
WHERE etiqueta != ''
GROUP BY etiqueta
ORDER BY frecuencia DESC
LIMIT 25;
```

---

## **3. Análisis de Combinaciones Reales**

### **3.1 MENU + OPCION - Combinaciones Efectivas**
```sql
-- Análisis de combinaciones menu-opción reales
SELECT 
    menu,
    COALESCE(opcion, 'SIN_OPCION') as opcion,
    COUNT(*) as frecuencia,
    
    -- Análisis de completitud
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as registros_incompletos,
    ROUND((COUNT(*) - SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END)) * 100.0 / COUNT(*), 2) as tasa_completitud,
    
    -- Análisis de transferencias
    SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) as transferencias,
    ROUND(SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_transferencia,
    
    -- Patrones de etiquetas más comunes
    (SELECT TRIM(TRAILING ',' FROM TRIM(etiquetas))
     FROM (
         SELECT * FROM llamadas_Q1
         UNION ALL SELECT * FROM llamadas_Q2
         UNION ALL SELECT * FROM llamadas_Q3
     ) sub 
     WHERE sub.menu = todas_llamadas.menu 
       AND COALESCE(sub.opcion, 'SIN_OPCION') = COALESCE(todas_llamadas.opcion, 'SIN_OPCION')
       AND sub.etiquetas IS NOT NULL 
       AND sub.etiquetas != ''
     GROUP BY TRIM(TRAILING ',' FROM TRIM(etiquetas))
     ORDER BY COUNT(*) DESC 
     LIMIT 1) as patron_etiquetas_principal,
     
    -- Clasificación de efectividad
    CASE 
        WHEN SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 70 THEN 'PROBLEMATICA'
        WHEN SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 50 THEN 'ALTA_TRANSFERENCIA'
        WHEN COUNT(*) < 5 THEN 'BAJA_FRECUENCIA'
        ELSE 'NORMAL'
    END as clasificacion
    
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE menu IS NOT NULL
GROUP BY menu, COALESCE(opcion, 'SIN_OPCION')
HAVING frecuencia >= 3
ORDER BY frecuencia DESC
LIMIT 30;
```

### **3.2 MENU + ETIQUETAS - Reglas de Negocio Reales**
```sql
-- Validación de reglas de negocio basada en datos observados
SELECT 
    menu_categoria,
    total_casos,
    casos_con_vsi,
    casos_con_zmb,
    casos_sin_etiquetas,
    
    -- Porcentajes de cumplimiento
    ROUND(casos_con_vsi * 100.0 / total_casos, 2) as porcentaje_vsi,
    ROUND(casos_con_zmb * 100.0 / total_casos, 2) as porcentaje_zmb,
    ROUND(casos_sin_etiquetas * 100.0 / total_casos, 2) as porcentaje_vacios,
    
    -- Evaluación de cumplimiento de reglas
    CASE 
        WHEN menu_categoria = 'TIPO_RES' AND casos_con_vsi * 100.0 / total_casos < 30 THEN 'REGLA_VSI_INCUMPLIDA'
        WHEN menu_categoria = 'DESBORDE' AND casos_con_zmb * 100.0 / total_casos < 50 THEN 'REGLA_ZMB_INCUMPLIDA'  
        WHEN casos_sin_etiquetas * 100.0 / total_casos > 60 THEN 'ALTO_ABANDONO'
        ELSE 'CUMPLIMIENTO_ACEPTABLE'
    END as evaluacion_reglas
    
FROM (
    SELECT 
        CASE 
            WHEN menu LIKE 'RES-%' THEN 'TIPO_RES'
            WHEN menu LIKE '%Desborde%' THEN 'DESBORDE'
            WHEN menu LIKE 'comercial_%' THEN 'COMERCIAL'
            WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 'ABANDONO'
            ELSE 'OTROS'
        END as menu_categoria,
        
        COUNT(*) as total_casos,
        SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as casos_con_vsi,
        SUM(CASE WHEN etiquetas LIKE '%ZMB%' THEN 1 ELSE 0 END) as casos_con_zmb,
        SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as casos_sin_etiquetas
        
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL SELECT * FROM llamadas_Q2
        UNION ALL SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE menu IS NOT NULL
    GROUP BY menu_categoria
) estadisticas_menu
ORDER BY total_casos DESC;
```

### **3.3 OPCION + ETIQUETAS - Consistencia de Procesamiento**
```sql
-- Análisis de consistencia opción → etiquetas
SELECT 
    opcion,
    COUNT(*) as total_usos,
    
    -- ¿La opción se refleja en las etiquetas?
    SUM(CASE 
        WHEN opcion = 'DEFAULT' THEN 1 -- DEFAULT no debe aparecer en etiquetas
        WHEN opcion IN ('2L', '1L', 'ML') AND etiquetas LIKE CONCAT('%', opcion, '%') THEN 1
        WHEN LENGTH(opcion) <= 2 THEN 1 -- Opciones numéricas cortas no se reflejan
        WHEN etiquetas LIKE CONCAT('%', opcion, '%') THEN 1
        ELSE 0
    END) as reflexion_correcta,
    
    -- Casos problemáticos específicos
    SUM(CASE WHEN opcion = '2L' AND etiquetas NOT LIKE '%2L%' AND etiquetas IS NOT NULL THEN 1 ELSE 0 END) as opcion_2l_no_reflejada,
    SUM(CASE WHEN opcion = 'CECOR' AND etiquetas NOT LIKE '%CECOR%' AND etiquetas IS NOT NULL THEN 1 ELSE 0 END) as opcion_cecor_no_reflejada,
    
    -- Tasa de procesamiento exitoso
    SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) as con_procesamiento,
    ROUND(SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_procesamiento,
    
    -- Ejemplos de etiquetas generadas
    SUBSTRING(GROUP_CONCAT(DISTINCT 
        CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' 
             THEN LEFT(etiquetas, 30) 
        END 
        ORDER BY etiquetas SEPARATOR ' | '), 1, 150) as ejemplos_etiquetas
    
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE opcion IS NOT NULL AND opcion != ''
GROUP BY opcion
HAVING total_usos >= 3
ORDER BY total_usos DESC
LIMIT 20;
```

---

## **4. Análisis Integral de Flujos Reales**

### **4.1 Flujos Completos Menu → Opción → Etiquetas → Resultado**
```sql
-- Análisis de flujos completos basado en datos reales
SELECT 
    CONCAT(
        COALESCE(menu, 'NULL_MENU'), 
        ' → ', 
        COALESCE(opcion, 'NULL_OPCION')
    ) as flujo_navegacion,
    
    COUNT(*) as volumen,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- Análisis de completitud del flujo
    SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) as flujos_procesados,
    ROUND(SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_completitud,
    
    -- Análisis de transferencias exitosas
    SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) as transferencias_exitosas,
    ROUND(SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as tasa_exito,
    
    -- Patrón de etiquetas más común en este flujo
    (SELECT TRIM(TRAILING ',' FROM TRIM(etiquetas))
     FROM (
         SELECT * FROM llamadas_Q1
         UNION ALL SELECT * FROM llamadas_Q2
         UNION ALL SELECT * FROM llamadas_Q3
     ) sub 
     WHERE COALESCE(sub.menu, 'NULL_MENU') = COALESCE(todas_llamadas.menu, 'NULL_MENU')
       AND COALESCE(sub.opcion, 'NULL_OPCION') = COALESCE(todas_llamadas.opcion, 'NULL_OPCION')
       AND sub.etiquetas IS NOT NULL 
       AND sub.etiquetas != ''
     GROUP BY TRIM(TRAILING ',' FROM TRIM(etiquetas))
     ORDER BY COUNT(*) DESC 
     LIMIT 1) as patron_etiquetas_dominante,
     
    -- Clasificación del flujo
    CASE 
        -- Flujos problemáticos identificados
        WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 'FLUJO_ABANDONO'
        WHEN menu IS NULL AND opcion IS NOT NULL THEN 'FLUJO_INCONSISTENTE'
        
        -- Flujos exitosos
        WHEN SUM(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 80
             AND SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 30
        THEN 'FLUJO_OPTIMO'
        
        -- Flujos con problemas de procesamiento
        WHEN SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 60
        THEN 'FLUJO_PROBLEMATICO'
        
        ELSE 'FLUJO_NORMAL'
    END as clasificacion_flujo
    
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
GROUP BY COALESCE(menu, 'NULL_MENU'), COALESCE(opcion, 'NULL_OPCION')
HAVING volumen >= 5
ORDER BY 
    CASE clasificacion_flujo
        WHEN 'FLUJO_OPTIMO' THEN 1
        WHEN 'FLUJO_NORMAL' THEN 2
        WHEN 'FLUJO_PROBLEMATICO' THEN 3
        WHEN 'FLUJO_INCONSISTENTE' THEN 4
        WHEN 'FLUJO_ABANDONO' THEN 5
    END,
    volumen DESC
LIMIT 25;
```

---

## **5. Detección de Anomalías Específicas**

### **5.1 Inconsistencias Detectadas en Datos Reales**
```sql
-- Detección de anomalías específicas observadas
SELECT 
    tipo_anomalia,
    COUNT(*) as casos_detectados,
    SUBSTRING(GROUP_CONCAT(DISTINCT 
        CONCAT('idRe:', idRe, ' Menu:', COALESCE(menu, 'NULL'), ' Opc:', COALESCE(opcion, 'NULL'))
        SEPARATOR ' | '), 1, 200) as ejemplos_casos
FROM (
    -- Anomalía 1: Menú NULL pero opción válida
    SELECT 'MENU_NULL_CON_OPCION' as tipo_anomalia, idRe, menu, opcion, etiquetas
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL SELECT * FROM llamadas_Q2
        UNION ALL SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE (menu IS NULL OR menu = '') AND (opcion IS NOT NULL AND opcion != '')
    
    UNION ALL
    
    -- Anomalía 2: RES sin VSI (violación de regla observada)
    SELECT 'RES_SIN_VSI', idRe, menu, opcion, etiquetas
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL SELECT * FROM llamadas_Q2
        UNION ALL SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE menu LIKE 'RES-%' 
      AND (etiquetas IS NULL OR etiquetas NOT LIKE '%VSI%')
      AND etiquetas IS NOT NULL
      AND etiquetas != ''
    
    UNION ALL
    
    -- Anomalía 3: Opción 2L sin etiqueta 2L
    SELECT 'OPCION_2L_NO_REFLEJADA', idRe, menu, opcion, etiquetas
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL SELECT * FROM llamadas_Q2
        UNION ALL SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE opcion = '2L' 
      AND (etiquetas IS NULL OR etiquetas NOT LIKE '%2L%')
      AND etiquetas IS NOT NULL
      AND etiquetas != ''
    
    UNION ALL
    
    -- Anomalía 4: Etiquetas terminan en múltiples comas
    SELECT 'ETIQUETAS_FORMATO_INCORRECTO', idRe, menu, opcion, etiquetas
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL SELECT * FROM llamadas_Q2
        UNION ALL SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE etiquetas IS NOT NULL 
      AND (etiquetas LIKE '%,,' OR etiquetas LIKE '%,,,' OR etiquetas RLIKE ',$')
      
) anomalias_detectadas
GROUP BY tipo_anomalia
ORDER BY casos_detectados DESC;
```

### **5.2 Análisis de Calidad por Trimestre**
```sql
-- Evolución de la calidad de datos por trimestre
SELECT 
    trimestre,
    COUNT(*) as total_registros,
    
    -- Completitud de campos
    SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END) as menu_faltante,
    SUM(CASE WHEN opcion IS NULL OR opcion = '' THEN 1 ELSE 0 END) as opcion_faltante,
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as etiquetas_faltantes,
    
    -- Calidad de etiquetas
    SUM(CASE WHEN etiquetas LIKE '%,,' THEN 1 ELSE 0 END) as etiquetas_doble_coma,
    SUM(CASE WHEN etiquetas RLIKE ',$' THEN 1 ELSE 0 END) as etiquetas_coma_final,
    
    -- Transferencias vs no transferencias
    SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) as sin_transferencia,
    SUM(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1 ELSE 0 END) as con_transferencia,
    
    -- Score de calidad por trimestre
    ROUND(100 - (
        (SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END) * 20.0 / COUNT(*)) +
        (SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 30.0 / COUNT(*)) +
        (SUM(CASE WHEN etiquetas LIKE '%,,' OR etiquetas RLIKE ',$' THEN 1 ELSE 0 END) * 10.0 / COUNT(*))
    ), 2) as score_calidad
    
FROM (
    SELECT *, 'Q1' as trimestre FROM llamadas_Q1
    UNION ALL
    SELECT *, 'Q2' as trimestre FROM llamadas_Q2
    UNION ALL
    SELECT *, 'Q3' as trimestre FROM llamadas_Q3
) por_trimestre
GROUP BY trimestre
ORDER BY trimestre;
```

---

## **6. Queries de Negocio Específicos**

### **6.1 Efectividad de Rutas IVR**
```sql
-- ¿Cuáles son las rutas más efectivas del IVR?
SELECT 
    'RUTA_EXITOSA' as tipo_ruta,
    menu,
    opcion,
    COUNT(*) as volumen,
    ROUND(AVG(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1.0 ELSE 0.0 END) * 100, 2) as tasa_procesamiento,
    ROUND(AVG(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1.0 ELSE 0.0 END) * 100, 2) as tasa_transferencia
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE menu IS NOT NULL 
  AND menu NOT IN ('cte_colgo', 'SinOpcion_Cbc')
GROUP BY menu, opcion
HAVING volumen >= 10
   AND tasa_procesamiento >= 70
   AND tasa_transferencia >= 30
ORDER BY volumen DESC

UNION ALL

SELECT 
    'RUTA_PROBLEMATICA' as tipo_ruta,
    menu,
    opcion,
    COUNT(*) as volumen,
    ROUND(AVG(CASE WHEN etiquetas IS NOT NULL AND etiquetas != '' THEN 1.0 ELSE 0.0 END) * 100, 2) as tasa_procesamiento,
    ROUND(AVG(CASE WHEN numero_entrada != COALESCE(numero_digitado, numero_entrada) THEN 1.0 ELSE 0.0 END) * 100, 2) as tasa_transferencia
FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL SELECT * FROM llamadas_Q2
    UNION ALL SELECT * FROM llamadas_Q3
) todas_llamadas
WHERE menu IS NOT NULL
GROUP BY menu, opcion
HAVING volumen >= 10
   AND (tasa_procesamiento < 30 OR tasa_transferencia < 5)
ORDER BY volumen DESC;
```

---

## **7. Respuestas a Preguntas de Negocio Específicas**

### **Preguntas que Responde este Análisis:**

1. **¿Por qué hay tantos registros sin etiquetas?**
   - Identificar menús con alta tasa de abandono
   - Detectar problemas de procesamiento del sistema

2. **¿Las validaciones (VSI) se ejecutan cuando deberían?**
   - Verificar cumplimiento de reglas en menús RES-*
   - Identificar fallos en el proceso de validación

3. **¿Los usuarios completan los flujos diseñados?**
   - Analizar rutas menu→opción→resultado
   - Detectar abandonos en puntos específicos

4. **¿Hay inconsistencias entre lo que selecciona el usuario y lo que registra el sistema?**
   - Verificar reflexión de opciones en etiquetas
   - Identificar desalineación proceso vs registro

5