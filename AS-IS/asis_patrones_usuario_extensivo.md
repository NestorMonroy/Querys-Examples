# AS-IS: Patrones de numero_entrada - Análisis Extensivo de Referencia

## Propósito
Documento de referencia completo que cataloga todos los tipos de análisis posibles sobre patrones de comportamiento de numero_entrada, desde básicos hasta complejos.

---

## 1. Análisis Básico de Patrones de Navegación

### **1.1 Reconstrucción de Journey Completo**

```sql
-- Secuencia temporal completa por usuario por día
SELECT 
    numero_entrada,
    fecha,
    COUNT(*) as total_interacciones_dia,
    
    -- Journey completo con timestamps corregidos
    GROUP_CONCAT(
        CONCAT(
            TIME_FORMAT(
                CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END, 
                '%H:%i:%s'
            ),
            ' [', COALESCE(menu, 'NULL'), 
            CASE WHEN opcion IS NOT NULL AND opcion != '' 
                 THEN CONCAT(':', opcion) ELSE ':NULL' END, ']',
            CASE WHEN etiquetas IS NOT NULL AND etiquetas != ''
                 THEN CONCAT(' {', LEFT(etiquetas, 20), '}') ELSE ' {SIN_ETIQ}' END,
            CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != ''
                 THEN CONCAT(' →', id_CTransferencia) ELSE '' END
        )
        ORDER BY CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END
        SEPARATOR ' | '
    ) as journey_detallado,
    
    -- Análisis de duración total
    TIME_TO_SEC(MAX(CASE WHEN hora_fin < hora_inicio THEN hora_inicio ELSE hora_fin END)) -
    TIME_TO_SEC(MIN(CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END)) as duracion_total_segundos,
    
    -- Análisis de redirecciones
    COUNT(DISTINCT id_CTransferencia) as destinos_redireccion_diferentes,
    GROUP_CONCAT(DISTINCT id_CTransferencia) as lista_redirecciones,
    
    -- Análisis de procesamiento
    COUNT(DISTINCT numero_digitado) as numeros_procesados,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as casos_procesamiento_interno,
    
    -- Análisis de validación
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as interacciones_validadas,
    SUM(CASE WHEN etiquetas LIKE '%NOBOT%' THEN 1 ELSE 0 END) as interacciones_humanas,
    SUM(CASE WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 1 ELSE 0 END) as interacciones_error,
    
    -- Contexto organizacional
    COUNT(DISTINCT id_8T) as zonas_utilizadas,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area)) as ubicaciones_organizacionales

FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL
    SELECT * FROM llamadas_Q2  
    UNION ALL
    SELECT * FROM llamadas_Q3
) todas_llamadas

WHERE numero_entrada IS NOT NULL
GROUP BY numero_entrada, fecha
ORDER BY numero_entrada, fecha;
```

### **1.2 Análisis de Secuencias de Transición**

```sql
-- Análisis de transiciones entre menús
WITH transiciones AS (
    SELECT 
        numero_entrada,
        fecha,
        menu as menu_actual,
        opcion as opcion_actual,
        LAG(menu) OVER (
            PARTITION BY numero_entrada, fecha 
            ORDER BY CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END
        ) as menu_anterior,
        LAG(opcion) OVER (
            PARTITION BY numero_entrada, fecha 
            ORDER BY CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END
        ) as opcion_anterior,
        
        -- Tiempo entre transiciones
        TIME_TO_SEC(
            CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END
        ) - LAG(TIME_TO_SEC(
            CASE WHEN hora_fin < hora_inicio THEN hora_inicio ELSE hora_fin END
        )) OVER (
            PARTITION BY numero_entrada, fecha 
            ORDER BY CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END
        ) as segundos_entre_interacciones,
        
        -- Contexto de la transición
        etiquetas,
        id_CTransferencia
        
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL
        SELECT * FROM llamadas_Q2  
        UNION ALL
        SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE numero_entrada IS NOT NULL AND menu IS NOT NULL
)
SELECT 
    CONCAT(COALESCE(menu_anterior, 'INICIO'), ':', COALESCE(opcion_anterior, 'NULL')) as desde,
    CONCAT(menu_actual, ':', COALESCE(opcion_actual, 'NULL')) as hacia,
    COUNT(*) as frecuencia_transicion,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    ROUND(AVG(segundos_entre_interacciones), 2) as tiempo_promedio_transicion,
    
    -- Análisis de éxito de la transición
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as transiciones_validadas,
    SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as transiciones_con_redireccion,
    
    -- Ejemplos de usuarios que siguen esta transición
    GROUP_CONCAT(DISTINCT numero_entrada LIMIT 5) as usuarios_ejemplo

FROM transiciones
WHERE menu_anterior IS NOT NULL
GROUP BY desde, hacia
HAVING frecuencia_transicion >= 5
ORDER BY frecuencia_transicion DESC;
```

---

## 2. Análisis Avanzado de Comportamiento

### **2.1 Segmentación Multi-dimensional de Usuarios**

```sql
-- Perfilado avanzado de usuarios por múltiples dimensiones
WITH perfil_completo AS (
    SELECT 
        numero_entrada,
        
        -- Dimensión Temporal
        COUNT(DISTINCT fecha) as dias_activos,
        COUNT(*) as total_interacciones,
        ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT fecha), 2) as intensidad_diaria,
        DATEDIFF(MAX(fecha), MIN(fecha)) + 1 as periodo_actividad_dias,
        
        -- Dimensión de Navegación
        COUNT(DISTINCT menu) as diversidad_menus,
        COUNT(DISTINCT CONCAT(menu, ':', opcion)) as diversidad_opciones,
        GROUP_CONCAT(DISTINCT menu ORDER BY menu) as menus_utilizados,
        
        -- Dimensión de Servicios
        SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) as servicios_resolucion,
        SUM(CASE WHEN menu LIKE 'comercial_%' THEN 1 ELSE 0 END) as interacciones_comerciales,
        SUM(CASE WHEN menu = 'SDO' THEN 1 ELSE 0 END) as consultas_saldo,
        SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas,
        SUM(CASE WHEN menu LIKE 'Desborde_%' THEN 1 ELSE 0 END) as experiencias_sobrecarga,
        
        -- Dimensión de Validación Sistema
        SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as validaciones_sistema,
        SUM(CASE WHEN etiquetas LIKE '%NOBOT%' THEN 1 ELSE 0 END) as confirmaciones_humano,
        SUM(CASE WHEN etiquetas LIKE '%NoTmx_SOMC%' THEN 1 ELSE 0 END) as errores_sistema,
        SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as sin_procesamiento,
        
        -- Dimensión de Redirección
        COUNT(DISTINCT id_CTransferencia) as destinos_redireccion,
        SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as interacciones_redirigidas,
        
        -- Dimensión Geográfico-Organizacional
        COUNT(DISTINCT id_8T) as zonas_geograficas,
        COUNT(DISTINCT division) as divisiones_utilizadas,
        COUNT(DISTINCT area) as areas_utilizadas,
        
        -- Dimensión de Procesamiento Interno
        SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as procesamiento_interno,
        COUNT(DISTINCT numero_digitado) as numeros_procesados_diferentes,
        
        -- Dimensión Temporal Avanzada
        COUNT(DISTINCT HOUR(CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END)) as horas_diferentes_uso,
        AVG(TIME_TO_SEC(CASE WHEN hora_fin < hora_inicio THEN hora_inicio ELSE hora_fin END) - 
            TIME_TO_SEC(CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END)) as duracion_promedio_interaccion
        
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL
        SELECT * FROM llamadas_Q2  
        UNION ALL
        SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE numero_entrada IS NOT NULL
    GROUP BY numero_entrada
)
SELECT 
    numero_entrada,
    
    -- Clasificación por Intensidad
    CASE 
        WHEN intensidad_diaria >= 20 THEN 'ULTRA_INTENSIVO'
        WHEN intensidad_diaria >= 10 THEN 'MUY_INTENSIVO'
        WHEN intensidad_diaria >= 5 THEN 'INTENSIVO'
        WHEN intensidad_diaria >= 2 THEN 'MODERADO'
        ELSE 'LIGERO'
    END as perfil_intensidad,
    
    -- Clasificación por Diversidad
    CASE 
        WHEN diversidad_menus >= 8 THEN 'EXPLORADOR_AVANZADO'
        WHEN diversidad_menus >= 5 THEN 'EXPLORADOR_MODERADO'
        WHEN diversidad_menus >= 3 THEN 'USUARIO_DIVERSO'
        WHEN diversidad_menus = 2 THEN 'USUARIO_DUAL'
        ELSE 'USUARIO_FOCALIZADO'
    END as perfil_diversidad,
    
    -- Clasificación por Tipo de Servicio
    CASE 
        WHEN servicios_resolucion > total_interacciones * 0.6 THEN 'ORIENTADO_SERVICIOS'
        WHEN interacciones_comerciales > 0 THEN 'PERFIL_COMERCIAL'
        WHEN consultas_saldo = total_interacciones THEN 'SOLO_CONSULTAS'
        WHEN interacciones_fallidas > total_interacciones * 0.5 THEN 'PROBLEMATICO'
        WHEN experiencias_sobrecarga > total_interacciones * 0.3 THEN 'AFECTADO_SOBRECARGA'
        ELSE 'MIXTO'
    END as perfil_servicio,
    
    -- Clasificación por Validación
    CASE 
        WHEN validaciones_sistema * 100.0 / total_interacciones >= 80 THEN 'ALTAMENTE_VALIDADO'
        WHEN confirmaciones_humano > 0 THEN 'INTERACCION_HUMANA_CONFIRMADA'
        WHEN errores_sistema > validaciones_sistema THEN 'AFECTADO_ERRORES_SISTEMA'
        WHEN sin_procesamiento * 100.0 / total_interacciones >= 70 THEN 'BAJO_PROCESAMIENTO'
        ELSE 'VALIDACION_MIXTA'
    END as perfil_validacion,
    
    -- Clasificación por Movilidad
    CASE 
        WHEN zonas_geograficas >= 5 THEN 'MULTI_ZONA_EXTREMO'
        WHEN zonas_geograficas >= 3 THEN 'MULTI_ZONA'
        WHEN divisiones_utilizadas >= 3 THEN 'MULTI_DIVISION'
        WHEN areas_utilizadas >= 3 THEN 'MULTI_AREA'
        ELSE 'GEOGRAFICAMENTE_ESTABLE'
    END as perfil_movilidad,
    
    -- Métricas detalladas
    total_interacciones,
    dias_activos,
    intensidad_diaria,
    diversidad_menus,
    ROUND(validaciones_sistema * 100.0 / total_interacciones, 1) as porcentaje_validado,
    ROUND(interacciones_fallidas * 100.0 / total_interacciones, 1) as porcentaje_fallidas,
    destinos_redireccion,
    zonas_geograficas
    
FROM perfil_completo
WHERE total_interacciones >= 2  -- Solo usuarios con al menos 2 interacciones
ORDER BY total_interacciones DESC;
```

### **2.2 Análisis de Clusters de Comportamiento**

```sql
-- Clustering automático basado en patrones de comportamiento
WITH metricas_normalizadas AS (
    SELECT 
        numero_entrada,
        
        -- Normalización de métricas (0-1)
        CASE 
            WHEN COUNT(*) <= 2 THEN 0.1
            WHEN COUNT(*) <= 5 THEN 0.3
            WHEN COUNT(*) <= 10 THEN 0.5
            WHEN COUNT(*) <= 20 THEN 0.7
            ELSE 0.9
        END as score_volumen,
        
        CASE 
            WHEN COUNT(DISTINCT menu) = 1 THEN 0.1
            WHEN COUNT(DISTINCT menu) <= 3 THEN 0.3
            WHEN COUNT(DISTINCT menu) <= 5 THEN 0.5
            WHEN COUNT(DISTINCT menu) <= 8 THEN 0.7
            ELSE 0.9
        END as score_diversidad,
        
        CASE 
            WHEN SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 80 THEN 0.9
            WHEN SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 60 THEN 0.7
            WHEN SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 40 THEN 0.5
            WHEN SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 20 THEN 0.3
            ELSE 0.1
        END as score_exito,
        
        CASE 
            WHEN SUM(CASE WHEN menu LIKE 'comercial_%' THEN 1 ELSE 0 END) > 0 THEN 0.9
            WHEN SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) > COUNT(*) * 0.5 THEN 0.7
            WHEN SUM(CASE WHEN menu = 'SDO' THEN 1 ELSE 0 END) = COUNT(*) THEN 0.3
            ELSE 0.5
        END as score_complejidad,
        
        -- Métricas base para referencia
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT menu) as menus_diferentes,
        SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as pct_exito

    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL
        SELECT * FROM llamadas_Q2  
        UNION ALL
        SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE numero_entrada IS NOT NULL
    GROUP BY numero_entrada
    HAVING COUNT(*) >= 2
),
clusters AS (
    SELECT *,
        -- Clustering basado en combinación de scores
        CASE 
            WHEN score_volumen >= 0.7 AND score_diversidad >= 0.7 THEN 'POWER_USER_EXPLORADOR'
            WHEN score_volumen >= 0.7 AND score_exito >= 0.7 THEN 'POWER_USER_EFICIENTE'
            WHEN score_complejidad >= 0.7 AND score_exito >= 0.7 THEN 'USUARIO_COMERCIAL_EXITOSO'
            WHEN score_diversidad >= 0.7 AND score_exito <= 0.3 THEN 'EXPLORADOR_PROBLEMATICO'
            WHEN score_volumen <= 0.3 AND score_complejidad <= 0.3 THEN 'USUARIO_SIMPLE'
            WHEN score_exito <= 0.3 AND score_volumen >= 0.5 THEN 'USUARIO_PROBLEMATICO_PERSISTENTE'
            WHEN score_diversidad <= 0.3 AND score_volumen >= 0.5 THEN 'USUARIO_REPETITIVO'
            ELSE 'USUARIO_ESTANDAR'
        END as cluster_comportamiento
    FROM metricas_normalizadas
)
SELECT 
    cluster_comportamiento,
    COUNT(*) as usuarios_en_cluster,
    
    -- Promedios del cluster
    ROUND(AVG(total_interacciones), 1) as promedio_interacciones,
    ROUND(AVG(menus_diferentes), 1) as promedio_diversidad_menus,
    ROUND(AVG(pct_exito), 1) as promedio_pct_exito,
    
    -- Rangos del cluster  
    MIN(total_interacciones) as min_interacciones,
    MAX(total_interacciones) as max_interacciones,
    MIN(pct_exito) as min_pct_exito,
    MAX(pct_exito) as max_pct_exito,
    
    -- Ejemplos de usuarios
    GROUP_CONCAT(numero_entrada ORDER BY total_interacciones DESC LIMIT 5) as usuarios_ejemplo_top,
    
    -- Scores promedio normalizados
    ROUND(AVG(score_volumen), 2) as score_promedio_volumen,
    ROUND(AVG(score_diversidad), 2) as score_promedio_diversidad,
    ROUND(AVG(score_exito), 2) as score_promedio_exito,
    ROUND(AVG(score_complejidad), 2) as score_promedio_complejidad

FROM clusters
GROUP BY cluster_comportamiento
ORDER BY usuarios_en_cluster DESC;
```

---

## 3. Análisis Temporal Avanzado

### **3.1 Análisis de Patrones Circadianos**

```sql
-- Patrones de uso por hora del día y día de la semana
SELECT 
    HOUR(CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END) as hora_del_dia,
    DAYOFWEEK(STR_TO_DATE(fecha, '%d/%m/%Y')) as dia_semana,
    DAYNAME(STR_TO_DATE(fecha, '%d/%m/%Y')) as nombre_dia,
    
    -- Volumen por hora-día
    COUNT(*) as total_interacciones,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_interacciones_por_usuario,
    
    -- Análisis de tipos de interacción por horario
    SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) as servicios_resolucion,
    SUM(CASE WHEN menu = 'SDO' THEN 1 ELSE 0 END) as consultas_saldo,
    SUM(CASE WHEN menu LIKE 'comercial_%' THEN 1 ELSE 0 END) as interacciones_comerciales,
    SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas,
    SUM(CASE WHEN menu LIKE 'Desborde_%' THEN 1 ELSE 0 END) as experiencias_sobrecarga,
    
    -- Tasas por horario
    ROUND(SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_validacion,
    ROUND(SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_abandono,
    ROUND(SUM(CASE WHEN menu LIKE 'Desborde_%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as tasa_sobrecarga,
    
    -- Duración promedio por horario
    ROUND(AVG(
        CASE 
            WHEN hora_fin < hora_inicio THEN TIME_TO_SEC(hora_inicio) - TIME_TO_SEC(hora_fin)
            ELSE TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)
        END
    ), 2) as duracion_promedio_segundos

FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL
    SELECT * FROM llamadas_Q2  
    UNION ALL
    SELECT * FROM llamadas_Q3
) todas_llamadas

WHERE numero_entrada IS NOT NULL
GROUP BY hora_del_dia, dia_semana, nombre_dia
ORDER BY dia_semana, hora_del_dia;
```

### **3.2 Análisis de Evolución Temporal de Usuarios**

```sql
-- Evolución del comportamiento de usuarios en el tiempo
WITH evolucion_usuario AS (
    SELECT 
        numero_entrada,
        fecha,
        ROW_NUMBER() OVER (PARTITION BY numero_entrada ORDER BY fecha) as sesion_numero,
        COUNT(*) as interacciones_sesion,
        
        -- Métricas por sesión
        COUNT(DISTINCT menu) as menus_sesion,
        SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as validaciones_sesion,
        SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as fallos_sesion,
        
        -- Tiempo total de la sesión
        TIME_TO_SEC(MAX(CASE WHEN hora_fin < hora_inicio THEN hora_inicio ELSE hora_fin END)) -
        TIME_TO_SEC(MIN(CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END)) as duracion_sesion_seg
        
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL
        SELECT * FROM llamadas_Q2  
        UNION ALL
        SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE numero_entrada IS NOT NULL
    GROUP BY numero_entrada, fecha
),
metricas_evolucion AS (
    SELECT 
        numero_entrada,
        COUNT(*) as total_sesiones,
        
        -- Análisis de primera vs última sesión
        MIN(CASE WHEN sesion_numero = 1 THEN interacciones_sesion END) as interacciones_primera_sesion,
        MAX(CASE WHEN sesion_numero = (SELECT MAX(sesion_numero) FROM evolucion_usuario eu2 WHERE eu2.numero_entrada = eu1.numero_entrada) 
                THEN interacciones_sesion END) as interacciones_ultima_sesion,
        
        MIN(CASE WHEN sesion_numero = 1 THEN validaciones_sesion END) as validaciones_primera_sesion,
        MAX(CASE WHEN sesion_numero = (SELECT MAX(sesion_numero) FROM evolucion_usuario eu2 WHERE eu2.numero_entrada = eu1.numero_entrada) 
                THEN validaciones_sesion END) as validaciones_ultima_sesion,
        
        -- Tendencias generales
        AVG(interacciones_sesion) as promedio_interacciones_por_sesion,
        AVG(menus_sesion) as promedio_menus_por_sesion,
        AVG(validaciones_sesion * 100.0 / interacciones_sesion) as promedio_tasa_validacion,
        AVG(fallos_sesion * 100.0 / interacciones_sesion) as promedio_tasa_fallos,
        AVG(duracion_sesion_seg) as promedio_duracion_sesion,
        
        -- Variabilidad
        STDDEV(interacciones_sesion) as variabilidad_interacciones,
        STDDEV(duracion_sesion_seg) as variabilidad_duracion
        
    FROM evolucion_usuario eu1
    GROUP BY numero_entrada
    HAVING total_sesiones >= 3  -- Solo usuarios con al menos 3 sesiones
)
SELECT 
    numero_entrada,
    total_sesiones,
    
    -- Análisis de aprendizaje/mejora
    interacciones_primera_sesion,
    interacciones_ultima_sesion,
    interacciones_ultima_sesion - interacciones_primera_sesion as cambio_interacciones,
    
    validaciones_primera_sesion,
    validaciones_ultima_sesion,
    validaciones_ultima_sesion - validaciones_primera_sesion as cambio_validaciones,
    
    -- Clasificación de evolución
    CASE 
        WHEN interacciones_ultima_sesion < interacciones_primera_sesion * 0.7 THEN 'MEJORO_EFICIENCIA'
        WHEN interacciones_ultima_sesion > interacciones_primera_sesion * 1.3 THEN 'AUMENTO_COMPLEJIDAD'
        WHEN validaciones_ultima_sesion > validaciones_primera_sesion THEN 'MEJORO_EXITO'
        WHEN variabilidad_interacciones <= promedio_interacciones_por_sesion * 0.3 THEN 'COMPORTAMIENTO_ESTABLE'
        ELSE 'SIN_PATRON_CLARO'
    END as patron_evolucion,
    
    -- Métricas de consistencia
    ROUND(promedio_interacciones_por_sesion, 2) as promedio_interacciones_por_sesion,
    ROUND(promedio_tasa_validacion, 1) as promedio_tasa_validacion,
    ROUND(variabilidad_interacciones, 2) as variabilidad_interacciones,
    
    CASE 
        WHEN variabilidad_interacciones <= promedio_interacciones_por_sesion * 0.2 THEN 'MUY_CONSISTENTE'
        WHEN variabilidad_interacciones <= promedio_interacciones_por_sesion * 0.5 THEN 'CONSISTENTE'
        WHEN variabilidad_interacciones <= promedio_interacciones_por_sesion * 0.8 THEN 'MODERADAMENTE_VARIABLE'
        ELSE 'ALTAMENTE_VARIABLE'
    END as nivel_consistencia

FROM metricas_evolucion
ORDER BY total_sesiones DESC, cambio_interacciones;
```

---

## 4. Análisis de Redes y Relaciones

### **4.1 Análisis de Redes de Redirección**

```sql
-- Mapeo de red de redirecciones entre usuarios y destinos
WITH red_redirecciones AS (
    SELECT 
        numero_entrada as nodo_origen,
        id_CTransferencia as nodo_destino,
        COUNT(*) as peso_conexion,
        COUNT(DISTINCT fecha) as dias_conexion,
        
        -- Contexto de la conexión
        GROUP_CONCAT(DISTINCT menu ORDER BY menu) as menus_generadores,
        GROUP_CONCAT(DISTINCT CONCAT(division, '-', area)) as ubicaciones,
        AVG(TIME_TO_SEC(CASE WHEN hora_fin < hora_inicio THEN hora_inicio ELSE hora_fin END) - 
            TIME_TO_SEC(CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END)) as duracion_promedio_antes_redireccion
        
    FROM (
        SELECT * FROM llamadas_Q1
        UNION ALL
        SELECT * FROM llamadas_Q2  
        UNION ALL
        SELECT * FROM llamadas_Q3
    ) todas_llamadas
    WHERE numero_entrada IS NOT NULL 
      AND id_CTransferencia IS NOT NULL 
      AND id_CTransferencia != ''
    GROUP BY numero_entrada, id_CTransferencia
),
estadisticas_nodos AS (
    -- Estadísticas de nodos origen (usuarios)
    SELECT 
        nodo_origen as nodo,
        'USUARIO' as tipo_nodo,
        COUNT(DISTINCT nodo_destino) as grado_salida,
        0 as grado_entrada,
        SUM(peso_conexion) as peso_total_salida,
        0 as peso_total_entrada
    FROM red_redirecciones
    GROUP BY nodo_origen
    
    UNION ALL
    
    -- Estadísticas de nodos destino
    SELECT 
        nodo_destino as nodo,
        'DESTINO' as tipo_nodo,
        0 as grado_salida,
        COUNT(DISTINCT nodo_origen) as grado_entrada,
        0 as peso_total_salida,
        SUM(peso_conexion) as peso_total_entrada
    FROM red_redirecciones
    GROUP BY nodo_destino
),
nodos_consolidados AS (
    SELECT 
        nodo,
        MAX(tipo_nodo) as tipo_