# 🔗 **Relación entre etiquetas, menu y opción**

## **Patrones Identificados en la Muestra**

### **Relaciones Claras Observadas:**

#### **1. Menu "comercial_X" → Etiquetas específicas**
```
menu: comercial_5, opcion: 5
etiquetas: (vacías, pero contexto comercial claro)
numero_digitado: diferente (transferencia a número comercial)
```

#### **2. Menu "RES-" → Patrones de etiquetas complejas**
```
menu: RES-ContratacionIfm_2024, opcion: DEFAULT
etiquetas: "2L,ZMB,VSI,NVS," / "1L,ZMB,VSI," / "ZMB,NVS,"
→ Procesos de contratación con validación sistema
```

#### **3. Menu "Desborde_Cabecera" → Etiquetas técnicas específicas**
```
menu: Desborde_Cabecera, opcion: TELCO
etiquetas: "1L,ZMB,WTS,VSI,TELCO," / "ZMB,WTS,TELCO,"
→ Sobrecarga con servicios TELCO específicos
```

#### **4. Menu de Error → Etiquetas vacías o error**
```
menu: cte_colgo, opcion: (vacía)
etiquetas: (vacías)
→ Interacciones fallidas sin procesamiento
```

#### **5. Menu "NoTMX-" → Etiquetas de error específicas**
```
menu: Desborde_Cabecera, opcion: NoTmx_SOMC  
etiquetas: "NoTmx_SOMC,NoTmx_SOMC,"
→ Error del sistema TMX duplicado en etiquetas
```

---

## **Análisis de Correlación**

### **Query para Identificar Patrones de Relación:**

```sql
-- CONCEPTO: ¿Cómo se correlacionan menu, opcion y etiquetas?
SELECT 
    menu,
    opcion,
    
    -- Análisis de etiquetas por menu/opcion
    COUNT(*) as total_casos,
    COUNT(DISTINCT etiquetas) as etiquetas_diferentes,
    
    -- Patrones de etiquetas más frecuentes
    GROUP_CONCAT(DISTINCT 
        CASE WHEN etiquetas != '' AND etiquetas IS NOT NULL 
        THEN etiquetas END 
        ORDER BY etiquetas LIMIT 3
    ) as etiquetas_principales,
    
    -- Análisis de códigos específicos por menu
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as casos_con_vsi,
    SUM(CASE WHEN etiquetas LIKE '%TELCO%' THEN 1 ELSE 0 END) as casos_con_telco,
    SUM(CASE WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 1 ELSE 0 END) as casos_con_error,
    SUM(CASE WHEN etiquetas LIKE '%NOBOT%' THEN 1 ELSE 0 END) as casos_con_nobot,
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as casos_sin_etiquetas,
    
    -- Porcentajes de cada tipo
    ROUND(SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_vsi,
    ROUND(SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_sin_etiquetas,
    
    -- Análisis de transferencias por menu/opcion
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as transferencias

FROM llamadas_Q1
GROUP BY menu, opcion
ORDER BY total_casos DESC
LIMIT 30;
```

### **Patrones Específicos Identificados:**

#### **Patrón 1: Menu Comercial → Sin Etiquetas Pero Con Transferencia**
- Menus tipo "comercial_X" tienden a no tener etiquetas de procesamiento
- Pero sí tienen transferencias a números específicos
- Interpretación: Las etiquetas no se generan para interacciones comerciales directas

#### **Patrón 2: Menu RES-* → Etiquetas Ricas en Validación**
- Siempre incluyen VSI, ZMB
- Suelen tener códigos de nivel (1L, 2L, ML)
- Interpretación: Los servicios de "respuesta/resolución" requieren validación completa

#### **Patrón 3: Menu Desborde_* + Opción Específica → Etiquetas Técnicas**
- Cuando opción = "TELCO" → etiquetas incluyen "TELCO"
- Cuando opción = "NoTmx_SOMC" → etiquetas replican el error
- Interpretación: Las etiquetas reflejan el estado/resultado del procesamiento

#### **Patrón 4: Menu Fallidos → Etiquetas Vacías**
- "cte_colgo", "SinOpcion_Cbc" → sin etiquetas
- Interpretación: Sin procesamiento exitoso = sin etiquetas de validación

---

## **Análisis Detallado de Interdependencia**

### **Query para Mapear Dependencias:**

```sql
-- CONCEPTO: Identificar reglas de negocio implícitas
WITH relaciones AS (
    SELECT 
        menu,
        opcion,
        etiquetas,
        COUNT(*) as frecuencia,
        
        -- Analizar si la opción aparece dentro de las etiquetas
        CASE WHEN etiquetas LIKE CONCAT('%', opcion, '%') THEN 'SI' ELSE 'NO' END as opcion_en_etiquetas,
        
        -- Analizar patrones de transferencia
        CASE WHEN numero_entrada != numero_digitado THEN 'CON_TRANSFERENCIA' ELSE 'SIN_TRANSFERENCIA' END as patron_transferencia,
        
        -- Analizar duración promedio
        ROUND(AVG(TIMESTAMPDIFF(SECOND, 
            STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
            STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
        )), 2) as duracion_promedio

    FROM llamadas_Q1
    WHERE menu IS NOT NULL
    GROUP BY menu, opcion, etiquetas, opcion_en_etiquetas, patron_transferencia
    HAVING frecuencia >= 2
)
SELECT 
    menu,
    opcion,
    
    -- ¿La opción se refleja en las etiquetas?
    SUM(CASE WHEN opcion_en_etiquetas = 'SI' THEN frecuencia ELSE 0 END) as casos_opcion_reflejada,
    SUM(frecuencia) as total_casos,
    ROUND(SUM(CASE WHEN opcion_en_etiquetas = 'SI' THEN frecuencia ELSE 0 END) * 100.0 / SUM(frecuencia), 1) as pct_opcion_reflejada,
    
    -- Análisis de patrones
    GROUP_CONCAT(DISTINCT 
        CASE WHEN opcion_en_etiquetas = 'SI' 
        THEN CONCAT('REFLEJA:', etiquetas) END 
        SEPARATOR ' | '
    ) as ejemplos_reflexion

FROM relaciones  
GROUP BY menu, opcion
HAVING total_casos >= 5
ORDER BY pct_opcion_reflejada DESC, total_casos DESC
LIMIT 20;
```

---

## **Reglas de Negocio Inferidas**

### **Regla 1: Reflexión de Opción en Etiquetas**
```
SI opcion = "TELCO" → etiquetas contienen "TELCO"
SI opcion = "NoTmx_SOMC" → etiquetas contienen "NoTmx_SOMC"
SI opcion = "MGC" → etiquetas contienen "MGC"
```

### **Regla 2: Validación según Tipo de Menu**
```
SI menu LIKE "RES-%" → etiquetas incluyen VSI + ZMB (validación obligatoria)
SI menu = "comercial_%" → etiquetas pueden estar vacías (validación no requerida)
SI menu LIKE "%colgo" → etiquetas vacías (fallo, no se procesa)
```

### **Regla 3: Códigos Técnicos según Contexto**
```
SI hay transferencia Y menu = "Desborde_*" → etiquetas incluyen código técnico
SI menu = "SDO" → etiquetas mínimas o vacías (consulta simple)
SI menu LIKE "NOTMX-%" → procesamiento especial, etiquetas específicas
```

---

## **Análisis Predictivo Basado en Relaciones**

### **Query para Validar Consistencia:**

```sql
-- CONCEPTO: ¿Las relaciones son consistentes o hay anomalías?
SELECT 
    'MENU_RES_SIN_VSI' as tipo_anomalia,
    COUNT(*) as casos_anomalos,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) LIMIT 5) as ejemplos
FROM llamadas_Q1
WHERE menu LIKE 'RES-%' 
  AND (etiquetas IS NULL OR etiquetas NOT LIKE '%VSI%')

UNION ALL

SELECT 
    'OPCION_NO_REFLEJADA_EN_ETIQUETAS' as tipo_anomalia,
    COUNT(*) as casos_anomalos,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) LIMIT 5) as ejemplos
FROM llamadas_Q1
WHERE opcion IS NOT NULL 
  AND opcion != '' 
  AND opcion NOT IN ('DEFAULT', '21', '1', '5', '11')
  AND (etiquetas IS NULL OR etiquetas NOT LIKE CONCAT('%', opcion, '%'))

UNION ALL

SELECT 
    'COMERCIAL_CON_ETIQUETAS_COMPLEJAS' as tipo_anomalia,
    COUNT(*) as casos_anomalos,
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) LIMIT 5) as ejemplos  
FROM llamadas_Q1
WHERE menu LIKE 'comercial_%'
  AND etiquetas IS NOT NULL 
  AND etiquetas != ''
  AND LENGTH(etiquetas) > 10

ORDER BY casos_anomalos DESC;
```

---

## **Interpretación AS-IS de las Relaciones**

### **Conclusiones:**

1. **Las etiquetas SON dependientes del menu y opción** - No son campos independientes
2. **Existen reglas de negocio implícitas** que determinan qué etiquetas se generan
3. **La opción frecuentemente se refleja en las etiquetas** como confirmación de procesamiento
4. **Los menus de error/fallo no generan etiquetas de validación** (comportamiento esperado)
5. **Los códigos técnicos en etiquetas corresponden al tipo de servicio** seleccionado en opción

### **Para tu Análisis de Promedio:**

Esta relación es crucial porque te permite:
- **Validar consistencia**: Detectar registros con relaciones anómalas
- **Filtrar calidad**: Usar solo combinaciones menu+opcion+etiquetas consistentes
- **Clasificar interacciones**: Según el nivel de procesamiento completado
- **Identificar patrones**: De comportamiento exitoso vs fallido

¿Te interesa analizar estas reglas de negocio implícitas para definir mejor qué constituye una "interacción válida" en tu reporte?