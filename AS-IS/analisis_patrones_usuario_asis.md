# 🔍 **AS-IS: Patrones de numero_entrada y Tipos de Análisis**

## **Interpretación de Patrones Reales en los Datos**

### **Patrón 1: Usuario con Múltiples Intentos Fallidos**
```
numero_entrada: 2185530869 (01/07/2025)
17:35:52 → SinOpcion_Cbc (Sin opción disponible)
17:38:01 → cte_colgo (Cliente colgó)  
17:40:40 → cte_colgo (Cliente colgó)
17:38:22 → Desborde_Cabecera + NoTmx_SOMC (Sobrecarga sistema)
```
**Interpretación**: Usuario frustrado por problemas del sistema

### **Patrón 2: Usuario con Journey de Transferencias Exitosas**
```
numero_entrada: 2169010041 (01/07/2025)
12:28:48 → Desborde_Cabecera [TELCO] → numero_digitado: 9899438399
12:35:17 → RES-SP_2024 [DEFAULT] → numero_digitado: 2694859708  
12:36:58 → RES-SP_2024 [DEFAULT] → numero_digitado: 2694810113
12:42:55 → RES-SP_2024 [DEFAULT] → numero_digitado: 2694812677
12:45:31 → RES-SP_2024 [DEFAULT] → numero_digitado: 2694810004
```
**Interpretación**: Usuario navegando exitosamente por múltiples servicios

### **Patrón 3: Usuario Power con Interacciones Repetitivas**
```
numero_entrada: 2169710858 (01/07/2025)
09:32:19 → cte_colgo
09:32:50 → cte_colgo  
09:36:41 → cte_colgo
09:37:08 → cte_colgo
```
**Interpretación**: Posible número interno o usuario con problemas específicos

### **Patrón 4: Usuario con Interacción Comercial Exitosa**
```
numero_entrada: 2248844857 (01/07/2025)
14:08:42 → comercial_5 [opcion: 5] → numero_digitado: 4389741603
etiquetas: [VALSIA20250701140923450-2255729118]
division: NORTE, area: QUERETARO
```
**Interpretación**: Interacción comercial completada satisfactoriamente

---

## **Tipos de Análisis AS-IS Posibles**

### **1. Análisis de Segmentación por Comportamiento**

#### **Clasificación de Usuarios por Patrón de Interacción**
```sql
-- CONCEPTO: Clasificar usuarios según su comportamiento observado
WITH patron_usuario AS (
    SELECT 
        numero_entrada,
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT fecha) as dias_activos,
        
        -- Análisis de menús utilizados
        SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas,
        SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) as interacciones_servicio,
        SUM(CASE WHEN menu LIKE 'comercial_%' THEN 1 ELSE 0 END) as interacciones_comerciales,
        SUM(CASE WHEN menu = 'SDO' THEN 1 ELSE 0 END) as consultas_saldo,
        
        -- Análisis de transferencias
        COUNT(DISTINCT numero_digitado) - 1 as transferencias_realizadas,
        
        -- Duración promedio por sesión
        AVG(TIMESTAMPDIFF(SECOND, 
            STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
            STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
        )) as duracion_promedio_seg
        
    FROM llamadas_Q1
    GROUP BY numero_entrada
)
SELECT 
    numero_entrada,
    total_interacciones,
    dias_activos,
    
    -- Clasificación por patrón
    CASE 
        WHEN interacciones_fallidas * 100.0 / total_interacciones > 70 THEN 'USUARIO_PROBLEMATICO'
        WHEN interacciones_comerciales > 0 THEN 'USUARIO_COMERCIAL'
        WHEN interacciones_servicio > interacciones_fallidas THEN 'USUARIO_SERVICIOS'
        WHEN consultas_saldo = total_interacciones THEN 'USUARIO_CONSULTA_SIMPLE'
        WHEN transferencias_realizadas > 3 THEN 'USUARIO_MULTI_SERVICIO'
        WHEN total_interacciones > 10 AND dias_activos = 1 THEN 'USUARIO_INTENSIVO'
        ELSE 'USUARIO_NORMAL'
    END as patron_comportamiento,
    
    interacciones_fallidas,
    interacciones_servicio,
    transferencias_realizadas,
    ROUND(duracion_promedio_seg, 2) as duracion_promedio_seg

FROM patron_usuario
ORDER BY total_interacciones DESC;
```

### **2. Análisis de Secuencias de Navegación**

#### **Identificación de Journeys Más Comunes**
```sql
-- CONCEPTO: ¿Cuáles son las secuencias de menú más frecuentes?
WITH secuencias_usuario AS (
    SELECT 
        numero_entrada,
        fecha,
        GROUP_CONCAT(
            CONCAT(menu, COALESCE(CONCAT(':', opcion), ''))
            ORDER BY STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s')
            SEPARATOR ' → '
        ) as secuencia_navegacion,
        COUNT(*) as pasos_total
    FROM llamadas_Q1
    WHERE menu IS NOT NULL
    GROUP BY numero_entrada, fecha
)
SELECT 
    secuencia_navegacion,
    COUNT(*) as frecuencia_secuencia,
    AVG(pasos_total) as promedio_pasos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- Ejemplos de usuarios que siguen este patrón
    GROUP_CONCAT(DISTINCT numero_entrada LIMIT 3) as usuarios_ejemplo
    
FROM secuencias_usuario
GROUP BY secuencia_navegacion
HAVING COUNT(*) >= 2  -- Solo secuencias que aparecen múltiples veces
ORDER BY frecuencia_secuencia DESC
LIMIT 20;
```

### **3. Análisis de Eficiencia de Menús**

#### **Identificar Menús/Opciones Más y Menos Efectivos**
```sql
-- CONCEPTO: ¿Qué menús generan más abandonos vs completaciones exitosas?
SELECT 
    menu,
    opcion,
    COUNT(*) as total_usos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- Análisis de efectividad
    SUM(CASE WHEN etiquetas LIKE '%VSI%' OR etiquetas LIKE '%ZMB%' THEN 1 ELSE 0 END) as interacciones_exitosas,
    SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas,
    
    -- Tasa de éxito
    ROUND(
        SUM(CASE WHEN etiquetas LIKE '%VSI%' OR etiquetas LIKE '%ZMB%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) as tasa_exito_pct,
    
    -- Análisis de transferencias
    COUNT(DISTINCT numero_digitado) as destinos_diferentes,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as transferencias,
    
    -- Duración promedio
    ROUND(AVG(TIMESTAMPDIFF(SECOND, 
        STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
        STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
    )), 2) as duracion_promedio_seg,
    
    -- Distribución por divisiones
    COUNT(DISTINCT division) as divisiones_activas,
    GROUP_CONCAT(DISTINCT division ORDER BY division LIMIT 3) as principales_divisiones

FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu, opcion
ORDER BY total_usos DESC;
```

### **4. Análisis de Red de Transferencias**

#### **Mapeo de Flujos entre numero_entrada y numero_digitado**
```sql
-- CONCEPTO: ¿Cómo fluyen las transferencias en el sistema?
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_transferencia,
    
    -- ¿Qué menús/opciones generan esta transferencia?
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menus_generadores,
    
    -- ¿En qué contexto organizacional?
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as contexto_organizacional,
    
    -- ¿Con qué etiquetas?
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR ' | ') as patron_etiquetas,
    
    -- Análisis temporal
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_transferencia,
    MAX(fecha) as ultima_transferencia,
    
    -- ¿Es bidireccional? (numero_digitado también aparece como numero_entrada)
    CASE WHEN EXISTS(
        SELECT 1 FROM llamadas_Q1 l2 
        WHERE l2.numero_entrada = l1.numero_digitado 
        AND l2.numero_digitado = l1.numero_entrada
    ) THEN 'SI' ELSE 'NO' END as es_bidireccional

FROM llamadas_Q1 l1
WHERE numero_entrada != numero_digitado 
  AND numero_digitado IS NOT NULL
  AND numero_digitado != ''
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_transferencia DESC
LIMIT 25;
```

### **5. Análisis Temporal de Comportamiento**

#### **Patrones de Uso por Horario y Día**
```sql
-- CONCEPTO: ¿Cuándo y cómo interactúan los usuarios?
SELECT 
    DATE_FORMAT(STR_TO_DATE(fecha, '%d/%m/%Y'), '%Y-%m-%d') as fecha_formateada,
    HOUR(STR_TO_DATE(hora_inicio, '%H:%i:%s')) as hora_del_dia,
    
    -- Volumen de interacciones
    COUNT(*) as total_interacciones,
    COUNT(DISTINCT numero_entrada) as usuarios_activos,
    
    -- Distribución por tipo de interacción
    SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) as servicios,
    SUM(CASE WHEN menu = 'SDO' THEN 1 ELSE 0 END) as consultas_saldo,
    SUM(CASE WHEN menu LIKE 'comercial_%' THEN 1 ELSE 0 END) as comerciales,
    SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as fallidas,
    
    -- Análisis de transferencias por horario
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as transferencias,
    
    -- Duración promedio por horario
    ROUND(AVG(TIMESTAMPDIFF(SECOND, 
        STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
        STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
    )), 2) as duracion_promedio_seg

FROM llamadas_Q1
GROUP BY fecha_formateada, hora_del_dia
ORDER BY fecha_formateada, hora_del_dia;
```

### **6. Análisis de Usuarios Anómalos**

#### **Detección de Comportamiento No Típico**
```sql
-- CONCEPTO: Identificar usuarios con patrones inusuales (internos, testing, etc.)
WITH metricas_usuario AS (
    SELECT 
        numero_entrada,
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT fecha) as dias_activos,
        COUNT(DISTINCT menu) as menus_diferentes,
        COUNT(DISTINCT numero_digitado) as numeros_destino,
        
        -- Intensidad de uso
        COUNT(*) / COUNT(DISTINCT fecha) as interacciones_por_dia,
        
        -- Patrones temporales
        MIN(STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s')) as primera_interaccion,
        MAX(STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')) as ultima_interaccion,
        
        -- Análisis de menús utilizados
        GROUP_CONCAT(DISTINCT menu ORDER BY menu) as menus_usados,
        
        -- Análisis geográfico
        COUNT(DISTINCT id_8T) as zonas_geograficas,
        COUNT(DISTINCT division) as divisiones_diferentes,
        
        -- Duración promedio
        AVG(TIMESTAMPDIFF(SECOND, 
            STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
            STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
        )) as duracion_promedio
    FROM llamadas_Q1
    GROUP BY numero_entrada
)
SELECT 
    numero_entrada,
    total_interacciones,
    dias_activos,
    interacciones_por_dia,
    menus_diferentes,
    numeros_destino,
    
    -- Clasificación de anomalía
    CASE 
        WHEN interacciones_por_dia > 50 THEN 'VOLUMEN_EXTREMO'
        WHEN menus_diferentes = 1 AND total_interacciones > 20 THEN 'MENU_UNICO_REPETITIVO'
        WHEN duracion_promedio < 2 THEN 'DURACION_SOSPECHOSA'
        WHEN zonas_geograficas > 5 THEN 'MULTI_ZONA_ANOMALO'
        WHEN divisiones_diferentes > 3 THEN 'MULTI_DIVISION_ANOMALO'
        WHEN dias_activos > 25 THEN 'USO_CONTINUO_SOSPECHOSO'
        ELSE 'NORMAL'
    END as tipo_anomalia,
    
    menus_usados,
    zonas_geograficas,
    divisiones_diferentes,
    ROUND(duracion_promedio, 2) as duracion_promedio_seg,
    
    DATE(primera_interaccion) as primera_fecha,
    DATE(ultima_interaccion) as ultima_fecha

FROM metricas_usuario
WHERE interacciones_por_dia > 20 
   OR menus_diferentes = 1 AND total_interacciones > 10
   OR duracion_promedio < 5
   OR zonas_geograficas > 3
ORDER BY interacciones_por_dia DESC;
```

### **7. Análisis de Clusters de Comportamiento**

#### **Agrupación de Usuarios por Similitud de Patrones**
```sql
-- CONCEPTO: ¿Qué grupos naturales de comportamiento existen?
WITH perfil_usuario AS (
    SELECT 
        numero_entrada,
        
        -- Métricas de volumen
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT fecha) as dias_activos,
        
        -- Métricas de diversidad
        COUNT(DISTINCT menu) as diversidad_menus,
        COUNT(DISTINCT numero_digitado) as diversidad_destinos,
        
        -- Métricas de comportamiento
        SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as pct_servicios,
        SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as pct_abandonos,
        SUM(CASE WHEN menu LIKE 'comercial_%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as pct_comercial,
        SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as pct_transferencias,
        
        -- Métricas temporales
        AVG(TIMESTAMPDIFF(SECOND, 
            STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
            STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
        )) as duracion_promedio
    FROM llamadas_Q1
    GROUP BY numero_entrada
)
SELECT 
    -- Segmentación por patrón de uso
    CASE 
        WHEN total_interacciones = 1 THEN 'SINGLE_TOUCH'
        WHEN pct_comercial > 50 THEN 'COMERCIAL_ORIENTED'
        WHEN pct_servicios > 60 THEN 'SERVICE_ORIENTED'  
        WHEN pct_abandonos > 50 THEN 'HIGH_DROPOUT'
        WHEN pct_transferencias > 40 THEN 'MULTI_SERVICE'
        WHEN total_interacciones > 15 AND dias_activos = 1 THEN 'INTENSIVE_SINGLE_DAY'
        WHEN dias_activos > 5 THEN 'RECURRING_USER'
        ELSE 'STANDARD_USER'
    END as cluster_comportamiento,
    
    COUNT(*) as usuarios_en_cluster,
    ROUND(AVG(total_interacciones), 2) as promedio_interacciones,
    ROUND(AVG(dias_activos), 2) as promedio_dias_activos,
    ROUND(AVG(pct_servicios), 1) as promedio_pct_servicios,
    ROUND(AVG(pct_abandonos), 1) as promedio_pct_abandonos,
    ROUND(AVG(duracion_promedio), 2) as promedio_duracion_seg,
    
    -- Ejemplos de usuarios en cada cluster
    GROUP_CONCAT(numero_entrada ORDER BY total_interacciones DESC LIMIT 3) as usuarios_ejemplo

FROM perfil_usuario
GROUP BY cluster_comportamiento
ORDER BY usuarios_en_cluster DESC;
```

---

## **Interpretaciones y Insights AS-IS**

### **Patrones Identificados:**

1. **Usuarios Problemáticos**: Múltiples `cte_colgo` consecutivos = Frustración del sistema
2. **Usuarios Multi-Servicio**: Múltiples transferencias exitosas = Power users legítimos  
3. **Usuarios Comerciales**: Acceden a `comercial_X` = Interacciones de negocio
4. **Usuarios Simples**: Solo `SDO` = Consultas básicas de saldo

### **Oportunidades de Análisis:**

1. **Optimización de UX**: Reducir secuencias que terminan en `cte_colgo`
2. **Análisis de Capacidad**: Identificar picos de `Desborde_Cabecera`
3. **Segmentación Comercial**: Perfilar usuarios por tipo de interacción
4. **Detección de Anomalías**: Identificar uso interno vs. clientes reales

**¿Cuál de estos análisis te interesa desarrollar más profundamente para tu reporte AS-IS?**