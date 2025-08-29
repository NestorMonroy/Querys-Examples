# 🏷️ **AS-IS: Análisis del Campo 'etiquetas'**

## **Patrones Identificados en las Etiquetas**

### **Análisis de la Muestra Real:**
```
Ejemplos encontrados:
- "2L,ZMB,VSI,NVS,"
- "1L,ZMB,DG,WTS,VSI,"  
- "NoTmx_SOMC,NoTmx_SOMC,"
- "1L,ZMB,NOBOT,VSI,"
- "ZMB,MGC,"
- "ML,ZMB,WTS,VSI,MGC,"
- (vacío)
```

### **Interpretación de Códigos Identificados:**

#### **Códigos de Sistema/Proceso:**
- **ZMB**: Aparece en ~90% de registros con etiquetas (¿Zona/Sistema base?)
- **VSI**: Muy frecuente, posiblemente "Validación Sistema Interno"
- **1L, 2L, ML**: Posibles niveles de servicio o líneas
- **WTS**: Sistema o proceso específico
- **DG**: Posible "Data Gateway" o similar

#### **Códigos de Estado/Validación:**
- **NoTmx_SOMC**: Error/excepción del sistema (No TMX - Sistema OMC)
- **NOBOT**: Indica interacción humana confirmada vs automatizada
- **NVS**: Posible "No Validación Sistema" o similar

#### **Códigos Funcionales:**
- **MGC, TELCO, TELECOB**: Tipos de servicio específicos
- **PSB_FLL_DSLAM_P**: Códigos técnicos de infraestructura
- **MIGRAFTTH**: Posible migración de tecnología
- **BDEMANDA**: Bajo demanda

---

## **Análisis Posibles con el Campo 'etiquetas'**

### **1. Análisis de Calidad/Validación de Interacciones**

```sql
-- CONCEPTO: Usar etiquetas para determinar calidad de la interacción
SELECT 
    CASE 
        WHEN etiquetas IS NULL OR etiquetas = '' THEN 'SIN_ETIQUETAS'
        WHEN etiquetas LIKE '%VSI%' AND etiquetas LIKE '%ZMB%' THEN 'VALIDADO_COMPLETO'
        WHEN etiquetas LIKE '%NOBOT%' THEN 'INTERACCION_HUMANA'
        WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 'ERROR_SISTEMA'
        WHEN etiquetas LIKE '%VSI%' THEN 'VALIDADO_PARCIAL'
        WHEN etiquetas LIKE '%ZMB%' THEN 'SISTEMA_BASE'
        ELSE 'OTROS_ESTADOS'
    END as categoria_validacion,
    
    COUNT(*) as total_registros,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- Análisis de comportamiento por categoría
    ROUND(AVG(TIMESTAMPDIFF(SECOND, 
        STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
        STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
    )), 2) as duracion_promedio_seg,
    
    -- Relación con menús
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_frecuentes,
    
    -- Análisis de transferencias por categoría
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as transferencias,
    ROUND(SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_transferencias

FROM llamadas_Q1
GROUP BY categoria_validacion
ORDER BY total_registros DESC;
```

### **2. Análisis de Niveles de Servicio (1L, 2L, ML)**

```sql
-- CONCEPTO: ¿Los códigos L indican escalamiento o tipo de servicio?
SELECT 
    CASE 
        WHEN etiquetas LIKE '%1L%' THEN '1L_PRIMER_NIVEL'
        WHEN etiquetas LIKE '%2L%' THEN '2L_SEGUNDO_NIVEL' 
        WHEN etiquetas LIKE '%ML%' THEN 'ML_MULTI_NIVEL'
        ELSE 'SIN_NIVEL_DEFINIDO'
    END as nivel_servicio,
    
    COUNT(*) as total_casos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- Análisis de efectividad por nivel
    SUM(CASE WHEN menu NOT IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_exitosas,
    ROUND(SUM(CASE WHEN menu NOT IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_exito_pct,
    
    -- Análisis de menús por nivel
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_por_nivel,
    
    -- Duración por nivel
    ROUND(AVG(TIMESTAMPDIFF(SECOND, 
        STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
        STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
    )), 2) as duracion_promedio_seg,
    
    -- Distribución geográfica por nivel
    COUNT(DISTINCT id_8T) as zonas_geograficas,
    COUNT(DISTINCT division) as divisiones_activas

FROM llamadas_Q1  
WHERE etiquetas IS NOT NULL AND etiquetas != ''
GROUP BY nivel_servicio
ORDER BY total_casos DESC;
```

### **3. Análisis de Códigos Técnicos/Infraestructura**

```sql
-- CONCEPTO: Identificar patrones técnicos en las etiquetas
WITH codigos_tecnicos AS (
    SELECT 
        numero_entrada,
        fecha,
        menu,
        etiquetas,
        
        -- Extraer códigos técnicos específicos
        CASE WHEN etiquetas LIKE '%MIGRAFTTH%' THEN 'MIGRACION_FIBRA' ELSE NULL END as migracion,
        CASE WHEN etiquetas LIKE '%PSB_FLL_DSLAM%' THEN 'DSLAM_PROCESS' ELSE NULL END as proceso_dslam,
        CASE WHEN etiquetas LIKE '%FM_CFE%' THEN 'FALLA_CFE' ELSE NULL END as falla_cfe,
        CASE WHEN etiquetas LIKE '%BDEMANDA%' THEN 'BAJO_DEMANDA' ELSE NULL END as bajo_demanda,
        CASE WHEN etiquetas LIKE '%TELECOB%' THEN 'TELECOBRANZA' ELSE NULL END as telecobranza,
        CASE WHEN etiquetas LIKE '%QJA_%' THEN 'PROCESO_QUEJA' ELSE NULL END as proceso_queja
        
    FROM llamadas_Q1
    WHERE etiquetas IS NOT NULL AND etiquetas != ''
)
SELECT 
    'MIGRACION_FIBRA' as tipo_codigo,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu LIMIT 3) as menus_asociados
FROM codigos_tecnicos WHERE migracion IS NOT NULL

UNION ALL

SELECT 
    'PROCESO_DSLAM' as tipo_codigo,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu LIMIT 3) as menus_asociados
FROM codigos_tecnicos WHERE proceso_dslam IS NOT NULL

UNION ALL

SELECT 
    'FALLA_CFE' as tipo_codigo,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu LIMIT 3) as menus_asociados
FROM codigos_tecnicos WHERE falla_cfe IS NOT NULL

UNION ALL

SELECT 
    'TELECOBRANZA' as tipo_codigo,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu LIMIT 3) as menus_asociados
FROM codigos_tecnicos WHERE telecobranza IS NOT NULL

UNION ALL

SELECT 
    'PROCESO_QUEJA' as tipo_codigo,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu LIMIT 3) as menus_asociados
FROM codigos_tecnicos WHERE proceso_queja IS NOT NULL

ORDER BY casos DESC;
```

### **4. Análisis de Segmentación de Usuarios por Etiquetas**

```sql
-- CONCEPTO: Clasificar usuarios según patrones en sus etiquetas
WITH perfil_etiquetas_usuario AS (
    SELECT 
        numero_entrada,
        COUNT(*) as total_interacciones,
        
        -- Análisis de códigos de validación
        SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as interacciones_vsi,
        SUM(CASE WHEN etiquetas LIKE '%NOBOT%' THEN 1 ELSE 0 END) as interacciones_humanas,
        SUM(CASE WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 1 ELSE 0 END) as interacciones_error,
        
        -- Análisis de niveles de servicio
        SUM(CASE WHEN etiquetas LIKE '%1L%' THEN 1 ELSE 0 END) as interacciones_nivel1,
        SUM(CASE WHEN etiquetas LIKE '%2L%' THEN 1 ELSE 0 END) as interacciones_nivel2,
        SUM(CASE WHEN etiquetas LIKE '%ML%' THEN 1 ELSE 0 END) as interacciones_multinivel,
        
        -- Análisis de procesos técnicos
        SUM(CASE WHEN etiquetas LIKE '%TELCO%' OR etiquetas LIKE '%TELECOB%' THEN 1 ELSE 0 END) as procesos_telco,
        SUM(CASE WHEN etiquetas LIKE '%QJA_%' THEN 1 ELSE 0 END) as procesos_queja,
        
        -- Sin etiquetas
        SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as sin_etiquetas
        
    FROM llamadas_Q1
    GROUP BY numero_entrada
)
SELECT 
    CASE 
        WHEN interacciones_error * 100.0 / total_interacciones > 50 THEN 'USUARIO_PROBLEMAS_SISTEMA'
        WHEN interacciones_humanas > 0 AND interacciones_vsi > 0 THEN 'USUARIO_MIXTO_HUMANO_SISTEMA'
        WHEN procesos_queja > 0 THEN 'USUARIO_CON_QUEJAS'
        WHEN procesos_telco > 0 THEN 'USUARIO_SERVICIOS_TELCO'
        WHEN interacciones_multinivel > 0 THEN 'USUARIO_MULTINIVEL'
        WHEN interacciones_nivel2 > 0 THEN 'USUARIO_ESCALADO'
        WHEN interacciones_vsi * 100.0 / total_interacciones > 80 THEN 'USUARIO_VALIDADO_SISTEMA'
        WHEN sin_etiquetas * 100.0 / total_interacciones > 70 THEN 'USUARIO_SIN_PROCESAMIENTO'
        ELSE 'USUARIO_ESTANDAR'
    END as perfil_usuario,
    
    COUNT(*) as usuarios_en_perfil,
    ROUND(AVG(total_interacciones), 2) as promedio_interacciones,
    ROUND(AVG(interacciones_vsi * 100.0 / total_interacciones), 1) as promedio_pct_vsi,
    ROUND(AVG(interacciones_humanas * 100.0 / total_interacciones), 1) as promedio_pct_humanas,
    ROUND(AVG(sin_etiquetas * 100.0 / total_interacciones), 1) as promedio_pct_sin_etiquetas

FROM perfil_etiquetas_usuario
WHERE total_interacciones > 1  -- Usuarios con al menos 2 interacciones
GROUP BY perfil_usuario
ORDER BY usuarios_en_perfil DESC;
```

### **5. Análisis de Correlación Etiquetas vs Comportamiento**

```sql
-- CONCEPTO: ¿Las etiquetas predicen el éxito/fallo de la interacción?
SELECT 
    menu,
    opcion,
    
    -- Distribución de etiquetas por menú
    COUNT(*) as total_usos,
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as con_vsi,
    SUM(CASE WHEN etiquetas LIKE '%NOBOT%' THEN 1 ELSE 0 END) as con_nobot,
    SUM(CASE WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 1 ELSE 0 END) as con_error,
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as sin_etiquetas,
    
    -- Tasas por menú
    ROUND(SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_vsi_pct,
    ROUND(SUM(CASE WHEN etiquetas LIKE '%NOBOT%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_nobot_pct,
    ROUND(SUM(CASE WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_error_pct,
    
    -- Análisis de transferencias por etiqueta
    SUM(CASE WHEN numero_entrada != numero_digitado AND etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as transferencias_vsi,
    SUM(CASE WHEN numero_entrada != numero_digitado AND (etiquetas IS NULL OR etiquetas = '') THEN 1 ELSE 0 END) as transferencias_sin_etiqueta,
    
    -- Duración promedio por presencia de etiquetas clave
    ROUND(AVG(CASE WHEN etiquetas LIKE '%VSI%' THEN 
        TIMESTAMPDIFF(SECOND, 
            STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
            STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
        ) END), 2) as duracion_promedio_vsi,
    ROUND(AVG(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 
        TIMESTAMPDIFF(SECOND, 
            STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
            STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
        ) END), 2) as duracion_promedio_sin_etiqueta

FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu, opcion
HAVING COUNT(*) >= 5  -- Solo menús con uso significativo
ORDER BY total_usos DESC
LIMIT 20;
```

### **6. Análisis Temporal de Etiquetas**

```sql
-- CONCEPTO: ¿Las etiquetas cambian según hora/día?
SELECT 
    DATE_FORMAT(STR_TO_DATE(fecha, '%d/%m/%Y'), '%Y-%m-%d') as fecha_formateada,
    HOUR(STR_TO_DATE(hora_inicio, '%H:%i:%s')) as hora_del_dia,
    
    COUNT(*) as total_interacciones,
    
    -- Distribución de etiquetas por horario
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as con_vsi,
    SUM(CASE WHEN etiquetas LIKE '%NOBOT%' THEN 1 ELSE 0 END) as con_nobot,
    SUM(CASE WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 1 ELSE 0 END) as con_error,
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as sin_etiquetas,
    
    -- Tasas por horario
    ROUND(SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_vsi_pct,
    ROUND(SUM(CASE WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_error_pct,
    ROUND(SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_sin_etiquetas_pct

FROM llamadas_Q1
GROUP BY fecha_formateada, hora_del_dia
HAVING total_interacciones >= 10  -- Solo horas con volumen significativo
ORDER BY fecha_formateada, hora_del_dia;
```

---

## **Interpretaciones AS-IS del Campo 'etiquetas'**

### **Hipótesis Basadas en Análisis:**

1. **VSI + ZMB = Interacción Validada y Procesada Exitosamente**
2. **NOBOT = Confirmación de Interacción Humana Real (vs automatizada)**
3. **NoTmx_SOMC = Falla del Sistema, Interacción No Procesable**
4. **1L/2L/ML = Niveles de Escalamiento o Tipos de Servicio**
5. **Sin Etiquetas = Interacción Incompleta o No Procesada**

### **Usos Prácticos de las Etiquetas:**

1. **Filtro de Calidad**: Usar VSI/ZMB para identificar interacciones válidas en reportes
2. **Segmentación**: Clasificar usuarios por tipo de proceso (humano vs automatizado)
3. **Análisis de Eficiencia**: Medir tasas de éxito por presencia de etiquetas específicas
4. **Detección de Problemas**: Identificar picos de NoTmx_SOMC como indicadores de fallas del sistema
5. **Análisis de Escalamiento**: Rastrear flujos de 1L → 2L → ML

### **Para tu Reporte AS-IS:**

El campo 'etiquetas' parece ser la **clave más confiable** para determinar:
- Validez de la interacción
- Tipo de procesamiento (humano/automatizado)  
- Estado de completitud del proceso
- Nivel de servicio aplicado

**¿Cuál de estos análisis de etiquetas sería más útil para interpretar el comportamiento real de tu sistema?**