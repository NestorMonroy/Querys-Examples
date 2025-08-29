# 🔍 **AS-IS: Interpretación de Data y Tipos de Análisis Posibles**

## 🎯 **Corrección del Enfoque - AS-IS Puro**

### **Lo que REALMENTE tenemos:**
- **3 tablas**: `llamadas_Q1`, `llamadas_Q2`, `llamadas_Q3`  
- **SIN limpiar aún** (estamos en AS-IS puro)
- **NO asumir validez** por `numero_entrada = numero_digitado`

### **El Problema Real de Interpretación:**
```
numero_entrada ≠ numero_digitado → NO significa "inválido"
numero_digitado = ¿el que confirma validez?
PERO numero_digitado puede aparecer en cualquiera de los campos
```

### **¿Cómo Determinar Patrones Reales?**
- **Por navegación**: `menu + opcion` que usan
- **Por etiquetas**: Campo `etiquetas` que aún no exploramos
- **Por comportamiento**: Patrones de interacción temporal

---

## 🧠 **Interpretación de Data Requerida**

### **Campos Clave para Entender:**

#### **A. Relación numero_entrada vs numero_digitado**
```sql
-- ¿Qué significa cuando son diferentes?
SELECT 
    'IGUALES' as relacion,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as numeros_unicos,
    ROUND(AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)), 2) as duracion_promedio
FROM llamadas_Q1
WHERE numero_entrada = numero_digitado

UNION ALL

SELECT 
    'DIFERENTES' as relacion,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as numeros_unicos,
    ROUND(AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)), 2) as duracion_promedio
FROM llamadas_Q1
WHERE numero_entrada != numero_digitado;
```

#### **B. Investigación Campo Etiquetas**
```sql
-- ¿Las etiquetas nos revelan el significado?
SELECT 
    etiquetas,
    COUNT(*) as frecuencia,
    COUNT(DISTINCT numero_entrada) as numeros_entrada_unicos,
    COUNT(DISTINCT numero_digitado) as numeros_digitado_unicos,
    
    -- ¿Hay patrón en la relación?
    SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) as iguales,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as diferentes,
    
    -- ¿Qué menús/opciones usan?
    COUNT(DISTINCT CONCAT(menu, ':', opcion)) as combinaciones_menu_opcion
FROM llamadas_Q1
WHERE etiquetas IS NOT NULL AND etiquetas != ''
GROUP BY etiquetas
ORDER BY frecuencia DESC;
```

#### **C. Análisis de Navegación por Relación**
```sql
-- ¿Los comportamientos son diferentes según numero_entrada vs numero_digitado?
SELECT 
    CASE WHEN numero_entrada = numero_digitado THEN 'IGUALES' ELSE 'DIFERENTES' END as tipo_relacion,
    menu,
    opcion,
    COUNT(*) as frecuencia_uso,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    ROUND(AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)), 2) as duracion_promedio,
    
    -- ¿Hay concentración en ciertos números?
    GROUP_CONCAT(DISTINCT numero_digitado ORDER BY numero_digitado SEPARATOR ',') as numeros_digitados_muestra
FROM llamadas_Q1
GROUP BY tipo_relacion, menu, opcion
ORDER BY tipo_relacion, frecuencia_uso DESC
LIMIT 20;
```

---

## 📊 **Tipos de Análisis AS-IS Posibles**

### **1. Análisis de Patrones de Usuario Individual**

#### **A. Journey Mapping por numero_entrada**
```sql
-- CONCEPTO: ¿Cuál es el journey completo de cada usuario?
SELECT 
    numero_entrada,
    DATE(fecha) as dia,
    COUNT(*) as total_interacciones,
    
    -- Journey reconstruido
    GROUP_CONCAT(
        CONCAT(
            TIME_FORMAT(hora_inicio, '%H:%i'), 
            ':[', menu, '-', opcion, ']'
        ) 
        ORDER BY hora_inicio 
        SEPARATOR ' → '
    ) as patron_navegacion_temporal,
    
    -- Análisis de diversidad
    COUNT(DISTINCT menu) as menus_visitados,
    COUNT(DISTINCT opcion) as opciones_diferentes,
    
    -- Contexto de números
    numero_digitado,
    CASE WHEN numero_entrada = numero_digitado THEN 'MISMO' ELSE 'DIFERENTE' END as relacion_numeros,
    
    -- Duración total sesión
    TIMEDIFF(MAX(hora_fin), MIN(hora_inicio)) as duracion_total_sesion
    
FROM llamadas_Q1
GROUP BY numero_entrada, DATE(fecha), numero_digitado
ORDER BY numero_entrada, dia;
```

#### **B. Segmentación por Intensidad de Uso**
```sql
-- CONCEPTO: Clasificar usuarios por nivel de interactividad
SELECT 
    CASE 
        WHEN interacciones_totales = 1 THEN '1_SINGLE_TOUCH'
        WHEN interacciones_totales BETWEEN 2 AND 5 THEN '2-5_MODERATE'
        WHEN interacciones_totales BETWEEN 6 AND 10 THEN '6-10_ACTIVE'
        WHEN interacciones_totales > 10 THEN '11+_POWER_USER'
    END as segmento_usuario,
    
    COUNT(DISTINCT numero_entrada) as cantidad_usuarios,
    AVG(interacciones_totales) as promedio_interacciones,
    AVG(menus_visitados) as promedio_menus,
    AVG(duracion_minutos) as duracion_promedio_min

FROM (
    SELECT 
        numero_entrada,
        COUNT(*) as interacciones_totales,
        COUNT(DISTINCT menu) as menus_visitados,
        AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)) / 60 as duracion_minutos
    FROM llamadas_Q1
    GROUP BY numero_entrada
) usuario_stats
GROUP BY segmento_usuario
ORDER BY segmento_usuario;
```

### **2. Análisis de Comportamiento del Sistema**

#### **A. Análisis de Menús más Utilizados**
```sql
-- CONCEPTO: ¿Cuáles son los puntos de navegación más frecuentes?
SELECT 
    menu,
    opcion,
    COUNT(*) as frecuencia_total,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- Eficiencia del menú
    ROUND(AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)), 2) as duracion_promedio_seg,
    
    -- Contexto de relación número
    SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) as con_numeros_iguales,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as con_numeros_diferentes,
    
    -- Distribución por zona
    COUNT(DISTINCT id_8T) as zonas_geograficas_activas,
    
    -- Análisis temporal
    COUNT(DISTINCT DATE(fecha)) as dias_activos
    
FROM llamadas_Q1
GROUP BY menu, opcion
ORDER BY frecuencia_total DESC;
```

#### **B. Análisis de Flujos de Navegación**
```sql
-- CONCEPTO: ¿Cuáles son las secuencias de navegación más comunes?
SELECT 
    paso_anterior,
    paso_actual,
    COUNT(*) as frecuencia_transicion,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    ROUND(AVG(tiempo_entre_pasos_seg), 2) as tiempo_promedio_transicion
FROM (
    SELECT 
        numero_entrada,
        fecha,
        CONCAT(menu, ':', opcion) as paso_actual,
        LAG(CONCAT(menu, ':', opcion)) OVER (
            PARTITION BY numero_entrada, fecha 
            ORDER BY hora_inicio
        ) as paso_anterior,
        TIME_TO_SEC(hora_inicio) - LAG(TIME_TO_SEC(hora_inicio)) OVER (
            PARTITION BY numero_entrada, fecha 
            ORDER BY hora_inicio
        ) as tiempo_entre_pasos_seg
    FROM llamadas_Q1
) transiciones
WHERE paso_anterior IS NOT NULL
GROUP BY paso_anterior, paso_actual
ORDER BY frecuencia_transicion DESC
LIMIT 20;
```

### **3. Análisis Temporal y Geográfico**

#### **A. Análisis de Patrones Horarios**
```sql
-- CONCEPTO: ¿Cuándo es más activo el sistema?
SELECT 
    HOUR(hora_inicio) as hora_del_dia,
    COUNT(*) as total_interacciones,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    ROUND(AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)), 2) as duracion_promedio,
    
    -- Distribución por tipo de relación números
    SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) as numeros_iguales,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as numeros_diferentes,
    
    -- Menús más frecuentes por hora
    GROUP_CONCAT(DISTINCT menu ORDER BY menu) as menus_activos
    
FROM llamadas_Q1
GROUP BY HOUR(hora_inicio)
ORDER BY hora_del_dia;
```

#### **B. Análisis por Zona Geográfica (id_8T)**
```sql
-- CONCEPTO: ¿Hay diferencias de comportamiento por zona?
SELECT 
    id_8T as zona_geografica,
    COUNT(*) as total_interacciones,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos_zona,
    COUNT(DISTINCT DATE(fecha)) as dias_activos,
    
    -- Promedio de interacciones por usuario por día en la zona
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada) / COUNT(DISTINCT DATE(fecha)), 2) as promedio_interacciones_usuario_dia,
    
    -- Análisis de relación números por zona
    ROUND(SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as porcentaje_numeros_iguales,
    
    -- Diversidad de navegación por zona
    COUNT(DISTINCT CONCAT(menu, ':', opcion)) as combinaciones_menu_opcion,
    
    -- Menús más populares por zona
    GROUP_CONCAT(DISTINCT menu ORDER BY menu) as menus_disponibles
    
FROM llamadas_Q1
GROUP BY id_8T
ORDER BY total_interacciones DESC;
```

### **4. Análisis de Calidad y Anomalías**

#### **A. Detección de Timestamps Problemáticos**
```sql
-- CONCEPTO: Entender patrones en timestamps invertidos SIN corregir aún
SELECT 
    'TIMESTAMPS_NORMALES' as tipo_timestamp,
    COUNT(*) as cantidad,
    ROUND(AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)), 2) as duracion_promedio_seg,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_frecuentes
FROM llamadas_Q1
WHERE TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) >= 0

UNION ALL

SELECT 
    'TIMESTAMPS_INVERTIDOS' as tipo_timestamp,
    COUNT(*) as cantidad,
    ROUND(AVG(TIME_TO_SEC(hora_inicio) - TIME_TO_SEC(hora_fin)), 2) as duracion_calculada_seg,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_frecuentes
FROM llamadas_Q1
WHERE TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0;
```

#### **B. Análisis de Números con Comportamiento Anómalo**
```sql
-- CONCEPTO: Identificar números con patrones inusuales
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as total_interacciones,
    COUNT(DISTINCT DATE(fecha)) as dias_activos,
    COUNT(DISTINCT menu) as menus_diferentes,
    COUNT(DISTINCT opcion) as opciones_diferentes,
    
    -- Intensidad de uso
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT DATE(fecha)), 2) as interacciones_por_dia,
    
    -- Patrón temporal
    MIN(fecha) as primera_aparicion,
    MAX(fecha) as ultima_aparicion,
    
    -- Duración promedio
    ROUND(AVG(ABS(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio))), 2) as duracion_promedio_seg,
    
    -- Clasificación de comportamiento
    CASE 
        WHEN COUNT(*) / COUNT(DISTINCT DATE(fecha)) > 20 THEN 'ALTO_VOLUMEN'
        WHEN COUNT(DISTINCT menu) = 1 AND COUNT(*) > 10 THEN 'MENU_UNICO'
        WHEN AVG(ABS(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio))) < 5 THEN 'DURACION_MUY_CORTA'
        WHEN COUNT(DISTINCT DATE(fecha)) > 30 THEN 'USO_CONTINUO'
        ELSE 'NORMAL'
    END as patron_comportamiento

FROM llamadas_Q1
GROUP BY numero_entrada, numero_digitado
ORDER BY total_interacciones DESC;
```

### **5. Análisis de Correlaciones y Relaciones**

#### **A. Relación entre Division/Area y Comportamiento**
```sql
-- CONCEPTO: ¿La estructura organizacional afecta el uso?
SELECT 
    division,
    area,
    COUNT(*) as total_interacciones,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    ROUND(AVG(COUNT(*)) OVER (PARTITION BY division, area), 2) as promedio_por_area,
    
    -- Distribución de relación números
    SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) as numeros_iguales,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as numeros_diferentes,
    
    -- Patrones de navegación
    COUNT(DISTINCT CONCAT(menu, ':', opcion)) as diversidad_navegacion,
    
    -- Distribución por zona geográfica
    COUNT(DISTINCT id_8T) as zonas_geograficas
    
FROM llamadas_Q1
WHERE division IS NOT NULL AND area IS NOT NULL
GROUP BY division, area
ORDER BY division, total_interacciones DESC;
```

---

## 🔍 **Queries Exploratorios AS-IS Necesarios**

### **Para Entender la Estructura Real de los Datos:**

```sql
-- 1. MUESTRA REPRESENTATIVA
SELECT 
    numero_entrada,
    numero_digitado, 
    menu,
    opcion,
    etiquetas,
    fecha,
    hora_inicio,
    hora_fin,
    division,
    area,
    id_8T,
    cIdentifica,
    nidMQ
FROM llamadas_Q1 
LIMIT 20;

-- 2. ANÁLISIS DE CAMPOS CLAVE
SELECT 
    'etiquetas' as campo,
    COUNT(DISTINCT etiquetas) as valores_distintos,
    SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) as valores_nulos
FROM llamadas_Q1
UNION ALL
SELECT 'cIdentifica' as campo, COUNT(DISTINCT cIdentifica), SUM(CASE WHEN cIdentifica IS NULL THEN 1 ELSE 0 END) FROM llamadas_Q1
UNION ALL  
SELECT 'nidMQ' as campo, COUNT(DISTINCT nidMQ), SUM(CASE WHEN nidMQ IS NULL THEN 1 ELSE 0 END) FROM llamadas_Q1;

-- 3. RANGOS DE VALORES
SELECT 
    MIN(numero_entrada) as min_numero_entrada,
    MAX(numero_entrada) as max_numero_entrada,
    MIN(numero_digitado) as min_numero_digitado,
    MAX(numero_digitado) as max_numero_digitado,
    COUNT(DISTINCT menu) as menus_distintos,
    COUNT(DISTINCT opcion) as opciones_distintas
FROM llamadas_Q1;
```

---

## 🎯 **Entregables AS-IS de Interpretación**

### **1. Reporte de Entendimiento de Data**
- **Significado real** de `numero_entrada` vs `numero_digitado`
- **Interpretación** del campo `etiquetas`
- **Patrones identificados** en la navegación

### **2. Análisis de Comportamiento de Usuarios**
- **Journey mapping** por usuario
- **Segmentación** por intensidad de uso
- **Patrones temporales** y geográficos

### **3. Análisis del Sistema**
- **Menús/opciones más utilizados**
- **Flujos de navegación** más comunes
- **Puntos de fricción** identificados

### **4. Recomendaciones para Análisis Avanzados**
- **Definición de validez** basada en patrones encontrados
- **Estrategia de limpieza** específica para los problemas reales
- **KPIs propuestos** basados en el comportamiento observado

---

**🔍 ¿Empezamos con los queries exploratorios para entender qué significan realmente los datos antes de cualquier interpretación?**