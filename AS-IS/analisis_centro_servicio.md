# 📞 **AS-IS: Centro de Servicio al Cliente - Journey Mapping y Abandono**

## 🎯 **Objetivo de Negocio**
**Mejorar la experiencia del cliente identificando dónde se frustran y abandonan, optimizando los flujos de autoservicio para reducir llamadas a agentes.**

---

## 📊 **Análisis Clave para Centro de Servicio**

### **1. MAPA DE JOURNEYS MÁS PROBLEMÁTICOS**

#### **A. Journeys con Mayor Tasa de Abandono**
```sql
-- ¿Qué secuencias de menú generan más abandono?
WITH journeys_completos AS (
    SELECT 
        numero_entrada,
        fecha,
        GROUP_CONCAT(
            CONCAT(menu, ':', opcion) 
            ORDER BY hora_inicio 
            SEPARATOR ' → '
        ) as secuencia_completa,
        COUNT(*) as total_pasos,
        TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as duracion_total_min,
        
        -- ¿Llegó a un menú de "resolución"? (ajustar según tu sistema)
        MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as llego_a_resolucion
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
    GROUP BY numero_entrada, fecha
    HAVING COUNT(*) > 1  -- Solo journeys con múltiples pasos
)
SELECT 
    secuencia_completa,
    COUNT(*) as frecuencia_journey,
    AVG(total_pasos) as promedio_pasos,
    AVG(duracion_total_min) as promedio_duracion_min,
    SUM(llego_a_resolucion) as completados_exitosos,
    COUNT(*) - SUM(llego_a_resolucion) as abandonados,
    ROUND((COUNT(*) - SUM(llego_a_resolucion)) * 100.0 / COUNT(*), 1) as tasa_abandono_pct,
    
    -- Nivel de frustración estimado
    CASE 
        WHEN AVG(duracion_total_min) > 10 AND (COUNT(*) - SUM(llego_a_resolucion)) * 100.0 / COUNT(*) > 70 THEN 'CRITICO'
        WHEN AVG(total_pasos) > 6 AND (COUNT(*) - SUM(llego_a_resolucion)) * 100.0 / COUNT(*) > 50 THEN 'ALTO'
        WHEN (COUNT(*) - SUM(llego_a_resolucion)) * 100.0 / COUNT(*) > 30 THEN 'MEDIO'
        ELSE 'BAJO'
    END as nivel_problematico
FROM journeys_completos
GROUP BY secuencia_completa
HAVING COUNT(*) >= 10  -- Solo journeys con volumen significativo
ORDER BY tasa_abandono_pct DESC, frecuencia_journey DESC
LIMIT 20;
```

#### **B. Puntos de Abandono por Menú/Opción**
```sql
-- ¿En qué menú/opción abandonan más los clientes?
WITH pasos_numerados AS (
    SELECT 
        numero_entrada, fecha, menu, opcion,
        hora_inicio, hora_fin,
        ROW_NUMBER() OVER (PARTITION BY numero_entrada, fecha ORDER BY hora_inicio) as numero_paso,
        COUNT(*) OVER (PARTITION BY numero_entrada, fecha) as total_pasos_sesion,
        CASE WHEN ROW_NUMBER() OVER (PARTITION BY numero_entrada, fecha ORDER BY hora_inicio DESC) = 1 
             THEN 1 ELSE 0 END as es_ultimo_paso
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
)
SELECT 
    menu,
    opcion,
    numero_paso,
    
    -- Métricas de abandono
    SUM(es_ultimo_paso) as veces_fue_punto_abandono,
    COUNT(*) as total_veces_visitado,
    ROUND(SUM(es_ultimo_paso) * 100.0 / COUNT(*), 1) as tasa_abandono_pct,
    
    -- Contexto del abandono
    AVG(CASE WHEN es_ultimo_paso = 1 THEN total_pasos_sesion END) as promedio_pasos_antes_abandono,
    AVG(CASE WHEN es_ultimo_paso = 1 
             THEN TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin) END) as tiempo_promedio_antes_abandono_seg,
    
    -- Clasificación del problema
    CASE 
        WHEN SUM(es_ultimo_paso) * 100.0 / COUNT(*) > 40 AND 
             AVG(CASE WHEN es_ultimo_paso = 1 
                      THEN TIMESTAMPDIFF(SECOND, hora_inicio, hora_fin) END) > 60 THEN 'PUNTO_CRITICO'
        WHEN SUM(es_ultimo_paso) * 100.0 / COUNT(*) > 25 THEN 'REQUIERE_ATENCION'
        ELSE 'NORMAL'
    END as clasificacion_abandono
FROM pasos_numerados
GROUP BY menu, opcion, numero_paso
HAVING COUNT(*) >= 20  -- Solo opciones con volumen significativo
ORDER BY tasa_abandono_pct DESC;
```

### **2. ANÁLISIS DE EFICIENCIA DE RESOLUCIÓN**

#### **A. Tiempo hasta Resolución por Tipo de Consulta**
```sql
-- ¿Cuánto tiempo toma resolver cada tipo de consulta?
WITH sesiones_clasificadas AS (
    SELECT 
        numero_entrada, fecha,
        MIN(hora_inicio) as inicio_sesion,
        MAX(hora_fin) as fin_sesion,
        TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as duracion_total_min,
        COUNT(*) as total_interacciones,
        
        -- Clasificar tipo de consulta basado en primer menú (ajustar según tu sistema)
        SUBSTRING_INDEX(GROUP_CONCAT(menu ORDER BY hora_inicio), ',', 1) as tipo_consulta_inicial,
        
        -- ¿Se resolvió exitosamente?
        MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as resuelto_exitosamente,
        
        -- Complejidad del journey
        COUNT(DISTINCT menu) as menus_diferentes_visitados
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
    GROUP BY numero_entrada, fecha
)
SELECT 
    tipo_consulta_inicial,
    COUNT(*) as total_sesiones,
    
    -- Métricas de eficiencia
    SUM(resuelto_exitosamente) as sesiones_exitosas,
    ROUND(SUM(resuelto_exitosamente) * 100.0 / COUNT(*), 1) as tasa_exito_pct,
    
    -- Tiempo de resolución
    AVG(CASE WHEN resuelto_exitosamente = 1 THEN duracion_total_min END) as tiempo_promedio_exito_min,
    AVG(CASE WHEN resuelto_exitosamente = 0 THEN duracion_total_min END) as tiempo_promedio_abandono_min,
    
    -- Complejidad
    AVG(total_interacciones) as promedio_interacciones,
    AVG(menus_diferentes_visitados) as promedio_menus_visitados,
    
    -- Recomendación de mejora
    CASE 
        WHEN SUM(resuelto_exitosamente) * 100.0 / COUNT(*) < 50 THEN 'REDISEÑAR_FLUJO'
        WHEN AVG(CASE WHEN resuelto_exitosamente = 1 THEN duracion_total_min END) > 8 THEN 'SIMPLIFICAR_PROCESO'
        WHEN AVG(total_interacciones) > 6 THEN 'REDUCIR_PASOS'
        ELSE 'OPTIMIZAR_CONTENIDO'
    END as recomendacion
FROM sesiones_clasificadas
GROUP BY tipo_consulta_inicial
ORDER BY total_sesiones DESC;
```

### **3. IDENTIFICACIÓN DE CLIENTES EN RIESGO**

#### **A. Clientes con Comportamiento de Alta Frustración**
```sql
-- ¿Qué clientes están más frustrados y podrían llamar a soporte?
WITH patron_cliente AS (
    SELECT 
        numero_entrada,
        COUNT(DISTINCT fecha) as dias_intentos,
        AVG(sesiones_por_dia.total_interacciones) as promedio_interacciones_por_sesion,
        AVG(sesiones_por_dia.duracion_min) as promedio_duracion_sesion,
        SUM(sesiones_por_dia.exito) as sesiones_exitosas,
        COUNT(DISTINCT sesiones_por_dia.fecha) as total_sesiones,
        
        -- Indicadores de frustración
        MAX(sesiones_por_dia.total_interacciones) as max_interacciones_una_sesion,
        MAX(sesiones_por_dia.duracion_min) as max_duracion_una_sesion
    FROM (
        SELECT 
            numero_entrada, fecha,
            COUNT(*) as total_interacciones,
            TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as duracion_min,
            MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as exito
        FROM llamadas_Q1 
        WHERE numero_entrada = numero_digitado
        GROUP BY numero_entrada, fecha
    ) sesiones_por_dia
    GROUP BY numero_entrada
    HAVING COUNT(DISTINCT fecha) >= 2  -- Al menos 2 intentos
)
SELECT 
    numero_entrada,
    dias_intentos,
    total_sesiones,
    promedio_interacciones_por_sesion,
    promedio_duracion_sesion,
    sesiones_exitosas,
    ROUND(sesiones_exitosas * 100.0 / total_sesiones, 1) as tasa_exito_pct,
    
    -- Score de frustración (0-100, mayor = más frustrado)
    LEAST(100, 
        (CASE WHEN promedio_duracion_sesion > 10 THEN 25 ELSE 0 END) +
        (CASE WHEN promedio_interacciones_por_sesion > 8 THEN 25 ELSE 0 END) +
        (CASE WHEN sesiones_exitosas * 100.0 / total_sesiones < 30 THEN 30 ELSE 0 END) +
        (CASE WHEN dias_intentos > 3 THEN 20 ELSE 0 END)
    ) as score_frustracion,
    
    -- Clasificación de riesgo
    CASE 
        WHEN sesiones_exitosas = 0 AND dias_intentos >= 3 THEN 'CRITICO_CONTACTAR'
        WHEN promedio_duracion_sesion > 12 AND sesiones_exitosas * 100.0 / total_sesiones < 40 THEN 'ALTO_RIESGO'
        WHEN promedio_interacciones_por_sesion > 10 THEN 'MEDIO_RIESGO'
        ELSE 'BAJO_RIESGO'
    END as nivel_riesgo
FROM patron_cliente
ORDER BY score_frustracion DESC, dias_intentos DESC
LIMIT 50;
```

---

## 🎯 **Insights Accionables para Centro de Servicio**

### **1. Acciones Inmediatas (Esta Semana)**

#### **🚨 Journeys Críticos a Rediseñar**
- Identificar las **top 5 secuencias con >70% abandono**
- Analizar el contenido/copy de esos menús específicos
- Crear versiones A/B test de esos flujos

#### **📞 Clientes en Riesgo Alto**  
- Lista de `numero_entrada` con score_frustracion > 80
- Contacto proactivo de servicio al cliente
- Ofercer asistencia personalizada antes de que llamen

#### **⚡ Puntos de Abandono Inmediatos**
- Menús/opciones con >40% de abandono requieren intervención urgente
- Revisar si el texto es confuso o la opción no funciona

### **2. Optimizaciones Semanales**

#### **📊 Dashboard de Monitoreo Continuo**
```sql
-- KPIs semanales para centro de servicio
SELECT 
    WEEK(fecha) as semana,
    
    -- Volumen y eficiencia
    COUNT(DISTINCT numero_entrada) as clientes_unicos,
    COUNT(*) as total_interacciones,
    AVG(interacciones_por_cliente) as promedio_interacciones_cliente,
    
    -- Tasa de éxito semanal
    SUM(sesiones_exitosas) as total_exitosas,
    COUNT(DISTINCT CONCAT(numero_entrada, fecha)) as total_sesiones,
    ROUND(SUM(sesiones_exitosas) * 100.0 / COUNT(DISTINCT CONCAT(numero_entrada, fecha)), 1) as tasa_exito_semanal,
    
    -- Tiempo promedio de resolución
    AVG(duracion_promedio_min) as tiempo_promedio_resolucion
FROM (
    SELECT 
        numero_entrada, fecha,
        WEEK(fecha) as semana,
        COUNT(*) as interacciones_por_cliente,
        MAX(CASE WHEN menu IN ('CONFIRMACION', 'EXITO', 'COMPLETADO') THEN 1 ELSE 0 END) as sesiones_exitosas,
        TIMESTAMPDIFF(MINUTE, MIN(hora_inicio), MAX(hora_fin)) as duracion_promedio_min
    FROM llamadas_Q1 
    WHERE numero_entrada = numero_digitado
    GROUP BY numero_entrada, fecha, WEEK(fecha)
) sesiones_semanales
GROUP BY WEEK(fecha)
ORDER BY semana;
```

### **3. Proyectos de Mejora (Mensual)**

#### **🔄 Rediseño de Flujos Problemáticos**
- Mapear journeys exitosos vs fallidos para el mismo tipo de consulta
- Identificar "atajos" que toman los usuarios exitosos
- Proponer flujos alternativos más directos

#### **🤖 Candidates para Automatización**
- Journeys muy repetitivos con alta tasa de éxito
- Consultas que siempre siguen el mismo patrón
- Implementar opciones de autoservicio más directas

---

## 📈 **Métricas de Éxito para Centro de Servicio**

### **KPIs Principales:**
- **Tasa de Resolución Automática**: % sesiones que terminan en éxito sin llamada
- **Tiempo Promedio hasta Resolución**: Minutos desde inicio hasta completar
- **Tasa de Abandono por Journey**: % de abandono por secuencia específica
- **Score de Frustración del Cliente**: Métrica compuesta de comportamiento problemático

### **Metas Trimestrales:**
- ⬆️ **+15% en tasa de resolución automática**
- ⬇️ **-30% en journeys con abandono >50%**  
- ⬇️ **-25% en tiempo promedio de resolución**
- ⬇️ **-40% en clientes con score frustración >80**

---

**🎯 Esta aproximación te permite identificar exactamente dónde están fallando tus clientes y actuar proactivamente antes de que escalen a llamadas costosas de soporte.**