# 🎯 **Solución Conceptual: Sistema de Reportes de Interacciones**

## 🧠 **Entendimiento del Problema**

### **¿Qué me están pidiendo exactamente?**
- **Reporte Principal**: Promedio de interacciones que tiene cada `numero_entrada` por día
- **Evolución Temporal**: Expandir a semana, mes, año
- **Estructura de Datos**: Por TRIMESTRES con fechas específicas ya definidas
- **Problema de Datos**: `numero_entrada` ≠ `numero_digitado` (¿son válidos? ¿qué significan?)
- **Calidad**: Timestamps invertidos que necesitan corrección

### **Estructura Temporal Definida:**
```
Q01_25: 2025-02-01 a 2025-03-31 (llamadas_Q1)
Q02_25: 2025-04-01 a 2025-06-30 (llamadas_Q2)  
Q03_25: 2025-07-01 a 2025-07-31 (llamadas_Q3)
```

### **¿Qué representa conceptualmente cada elemento?**
- **`numero_entrada`** = Usuario/Cliente que inicia la interacción
- **`numero_digitado`** = ¿Destino? ¿Número procesado? ¿Enrutamiento?
- **`id_8T`** = Grupo de zonas geográficas (segmentación territorial)
- **Un registro** = Una acción/decisión en el menú del sistema
- **Múltiples registros por día** = Journey completo del usuario
- **Trimestre** = Unidad de análisis temporal y particionamiento de datos

## 📋 **Análisis AS-IS: Contexto por Trimestres**

### **Datos Disponibles por Período:**
```sql
-- Variables ya definidas
SET @Q1_nombre = 'Q01_25';
SET @Q1_inicio = '2025-02-01'; 
SET @Q1_fin = '2025-03-31';    -- 59 días hábiles

SET @Q2_nombre = 'Q02_25';
SET @Q2_inicio = '2025-04-01';
SET @Q2_fin = '2025-06-30';    -- 91 días hábiles

SET @Q3_nombre = 'Q03_25';  
SET @Q3_inicio = '2025-07-01';
SET @Q3_fin = '2025-07-31';    -- 31 días hábiles (¿período incompleto?)
```

### **Consideraciones Temporales AS-IS:**
- **Q1**: Período completo (Feb-Mar) = Base de comparación
- **Q2**: Período completo (Abr-Jun) = Comparativo estacional  
- **Q3**: **¿Período parcial?** (Solo Julio) = Validar si es completo o en construcción

### **Preguntas AS-IS Inmediatas:**
1. **¿Q3 está completo o aún capturando datos?**
2. **¿Los rangos de fechas reflejan períodos operativos o calendario?**
3. **¿Hay estacionalidad conocida entre trimestres?**

---

## 🔍 **Modelo Conceptual de Análisis**

### **Definición de Entidades**

```
USUARIO (numero_entrada) 
├── ZONA GEOGRÁFICA (id_8T)
├── TRIMESTRE (Q01_25, Q02_25, Q03_25)
    └── SESIÓN DIARIA (numero_entrada + fecha)
        ├── INTERACCIÓN 1 (registro 1: menú X, opción Y)
        ├── INTERACCIÓN 2 (registro 2: menú Z, opción W)
        └── INTERACCIÓN N (registro N: menú A, opción B)
```

### **Clasificación de Llamadas**

```
LLAMADAS OFICIALES: numero_entrada = numero_digitado
├── Comportamiento "normal" del usuario
├── Journey directo en el sistema
└── Base para cálculo de promedios

LLAMADAS DERIVADAS: numero_entrada ≠ numero_digitado  
├── ¿Transferencias internas?
├── ¿Enrutamiento automático?
├── ¿Números de prueba/testing?
└── INVESTIGAR: ¿Incluir en promedios o no?
```

---

## 🏗️ **Arquitectura de Solución**

### **Capa 1: Preparación de Datos**

#### **A. Corrección de Calidad (Por Trimestre)**
```sql
-- CONCEPTO: Vista unificada con datos limpios POR TRIMESTRE
CREATE VIEW v_interacciones_limpias AS
SELECT 
    idRe, numero_entrada, numero_digitado, fecha, menu, opcion,
    division, area, id_8T,
    
    -- ✅ IDENTIFICACIÓN DE TRIMESTRE
    CASE 
        WHEN fecha BETWEEN @Q1_inicio AND @Q1_fin THEN @Q1_nombre
        WHEN fecha BETWEEN @Q2_inicio AND @Q2_fin THEN @Q2_nombre  
        WHEN fecha BETWEEN @Q3_inicio AND @Q3_fin THEN @Q3_nombre
        ELSE 'FUERA_RANGO'
    END as trimestre,
    
    -- ✅ CORRECCIÓN TIMESTAMPS
    CASE 
        WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 
        THEN hora_fin  -- Estaban invertidos
        ELSE hora_inicio 
    END as hora_inicio_real,
    
    CASE 
        WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 
        THEN hora_inicio  -- Estaban invertidos
        ELSE hora_fin 
    END as hora_fin_real,
    
    -- ✅ CLASIFICACIÓN DE LLAMADAS
    CASE 
        WHEN numero_entrada = numero_digitado THEN 'OFICIAL'
        ELSE 'DERIVADO'
    END as tipo_llamada,
    
    -- ✅ METADATA DE CALIDAD
    CASE 
        WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 
        THEN 'TIMESTAMP_CORREGIDO'
        ELSE 'TIMESTAMP_ORIGINAL'
    END as calidad_dato
    
FROM (
    SELECT *, 'Q1' as fuente_tabla FROM llamadas_Q1 
    WHERE fecha BETWEEN @Q1_inicio AND @Q1_fin
    
    UNION ALL
    
    SELECT *, 'Q2' as fuente_tabla FROM llamadas_Q2
    WHERE fecha BETWEEN @Q2_inicio AND @Q2_fin
    
    UNION ALL
    
    SELECT *, 'Q3' as fuente_tabla FROM llamadas_Q3  
    WHERE fecha BETWEEN @Q3_inicio AND @Q3_fin
) todas_llamadas
WHERE fecha BETWEEN @Q1_inicio AND @Q3_fin;  -- Solo datos válidos
```

#### **B. Investigación de Comportamiento**
```sql
-- CONCEPTO: Entender llamadas DERIVADAS
CREATE VIEW v_analisis_derivados AS
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_uso,
    COUNT(DISTINCT fecha) as dias_activos,
    AVG(TIME_TO_SEC(hora_fin_real) - TIME_TO_SEC(hora_inicio_real)) as duracion_promedio,
    
    -- Patrones de navegación
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion)) as opciones_usadas,
    
    -- ¿Comportamiento sospechoso?
    CASE 
        WHEN COUNT(DISTINCT fecha) > 30 THEN 'POSIBLE_INTERNO'
        WHEN AVG(TIME_TO_SEC(hora_fin_real) - TIME_TO_SEC(hora_inicio_real)) < 5 THEN 'AUTOMATICO'
        WHEN COUNT(*) / COUNT(DISTINCT fecha) > 20 THEN 'ALTO_VOLUMEN'
        ELSE 'NORMAL'
    END as patron_comportamiento
    
FROM v_interacciones_limpias
WHERE tipo_llamada = 'DERIVADO'
GROUP BY numero_entrada, numero_digitado;
```

### **Capa 2: Agregación por Usuario/Día**

#### **A. Sesiones Diarias de Usuario (Con Contexto Trimestral)**
```sql
-- CONCEPTO: Consolidación de journey por usuario por día POR TRIMESTRE
CREATE VIEW v_sesiones_diarias AS
SELECT 
    trimestre,
    numero_entrada,
    fecha,
    tipo_llamada,
    id_8T,  -- Grupo de zonas geográficas
    division, area,
    
    -- ✅ MÉTRICAS PRINCIPALES
    COUNT(*) as total_interacciones,
    MIN(hora_inicio_real) as primera_interaccion,
    MAX(hora_fin_real) as ultima_interaccion,
    
    -- Journey del usuario
    GROUP_CONCAT(
        CONCAT(menu, ':', opcion) 
        ORDER BY hora_inicio_real 
        SEPARATOR ' → '
    ) as journey_navegacion,
    
    -- Diversidad de menús visitados
    COUNT(DISTINCT menu) as menus_visitados,
    COUNT(DISTINCT opcion) as opciones_diferentes,
    
    -- Duración total de la sesión
    TIME_TO_SEC(MAX(hora_fin_real)) - TIME_TO_SEC(MIN(hora_inicio_real)) as duracion_sesion_seg
    
FROM v_interacciones_limpias
GROUP BY trimestre, numero_entrada, fecha, tipo_llamada, id_8T, division, area;
```

### **Capa 3: Reportes Solicitados**

#### **A. Reporte Diario (REQUERIMIENTO PRINCIPAL CON TRIMESTRES)**
```sql
-- CONCEPTO: Promedio de interacciones por número por día POR TRIMESTRE
CREATE VIEW v_reporte_diario AS
SELECT 
    trimestre,
    fecha,
    tipo_llamada,
    
    -- Segmentación geográfica
    id_8T as grupo_zonas,
    
    -- ✅ MÉTRICAS SOLICITADAS
    COUNT(DISTINCT numero_entrada) as usuarios_activos,
    SUM(total_interacciones) as interacciones_totales,
    
    -- 🎯 REPORTE PRINCIPAL: PROMEDIO
    ROUND(AVG(total_interacciones), 2) as promedio_interacciones_por_usuario,
    
    -- Métricas complementarias
    MIN(total_interacciones) as min_interacciones,
    MAX(total_interacciones) as max_interacciones,
    ROUND(STDDEV(total_interacciones), 2) as desviacion_estandar,
    
    -- Distribución de usuarios por nivel de interacción
    SUM(CASE WHEN total_interacciones = 1 THEN 1 ELSE 0 END) as usuarios_1_interaccion,
    SUM(CASE WHEN total_interacciones BETWEEN 2 AND 5 THEN 1 ELSE 0 END) as usuarios_2a5_interacciones,
    SUM(CASE WHEN total_interacciones > 5 THEN 1 ELSE 0 END) as usuarios_mas5_interacciones,
    
    -- Eficiencia temporal
    ROUND(AVG(duracion_sesion_seg), 2) as duracion_promedio_sesion
    
FROM v_sesiones_diarias
GROUP BY trimestre, fecha, tipo_llamada, id_8T
ORDER BY trimestre, fecha, tipo_llamada, id_8T;
```

#### **B. Reportes Temporales Extendidos (Con Agrupación Trimestral)**
```sql
-- CONCEPTO: Escalabilidad temporal (semana, mes, año) RESPETANDO TRIMESTRES

-- 📅 REPORTE SEMANAL
CREATE VIEW v_reporte_semanal AS
SELECT 
    trimestre,
    YEAR(fecha) as año,
    WEEK(fecha, 1) as semana,
    tipo_llamada,
    id_8T as grupo_zonas,
    
    COUNT(DISTINCT fecha) as dias_con_datos,
    ROUND(AVG(promedio_interacciones_por_usuario), 2) as promedio_semanal,
    ROUND(AVG(usuarios_activos), 0) as usuarios_promedio_dia,
    SUM(interacciones_totales) as interacciones_totales_semana
    
FROM v_reporte_diario
GROUP BY trimestre, YEAR(fecha), WEEK(fecha, 1), tipo_llamada, id_8T;

-- 📅 REPORTE MENSUAL  
CREATE VIEW v_reporte_mensual AS
SELECT 
    trimestre,
    YEAR(fecha) as año,
    MONTH(fecha) as mes,
    tipo_llamada,
    id_8T as grupo_zonas,
    
    COUNT(DISTINCT fecha) as dias_con_datos,
    ROUND(AVG(promedio_interacciones_por_usuario), 2) as promedio_mensual,
    ROUND(AVG(usuarios_activos), 0) as usuarios_promedio_dia,
    SUM(interacciones_totales) as interacciones_totales_mes
    
FROM v_reporte_diario  
GROUP BY trimestre, YEAR(fecha), MONTH(fecha), tipo_llamada, id_8T;

-- 📅 REPORTE TRIMESTRAL (NUEVO - MUY RELEVANTE)
CREATE VIEW v_reporte_trimestral AS
SELECT 
    trimestre,
    tipo_llamada,
    id_8T as grupo_zonas,
    
    COUNT(DISTINCT fecha) as dias_con_datos,
    ROUND(AVG(promedio_interacciones_por_usuario), 2) as promedio_trimestral,
    ROUND(AVG(usuarios_activos), 0) as usuarios_promedio_dia,
    SUM(interacciones_totales) as interacciones_totales_trimestre,
    
    -- Comparativo entre trimestres
    COUNT(DISTINCT numero_entrada) as usuarios_unicos_trimestre
    
FROM v_reporte_diario rd
JOIN v_sesiones_diarias sd ON (rd.trimestre = sd.trimestre AND rd.fecha = sd.fecha)
GROUP BY trimestre, tipo_llamada, id_8T;

-- 📅 REPORTE ANUAL (Consolidado por Trimestre)
CREATE VIEW v_reporte_anual AS
SELECT 
    YEAR(fecha) as año,
    tipo_llamada,
    id_8T as grupo_zonas,
    
    GROUP_CONCAT(DISTINCT trimestre ORDER BY trimestre) as trimestres_incluidos,
    COUNT(DISTINCT fecha) as dias_con_datos,
    ROUND(AVG(promedio_interacciones_por_usuario), 2) as promedio_anual,
    ROUND(AVG(usuarios_activos), 0) as usuarios_promedio_dia,
    SUM(interacciones_totales) as interacciones_totales_año
    
FROM v_reporte_diario
GROUP BY YEAR(fecha), tipo_llamada, id_8T;
```

---

## 🔬 **Investigación: numero_entrada ≠ numero_digitado**

### **Hipótesis a Validar**

#### **Hipótesis 1: Enrutamiento/Transferencias**
```sql
-- ¿numero_digitado representa el destino final?
SELECT 
    'OFICIAL' as tipo,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    AVG(total_interacciones) as promedio_interacciones,
    AVG(menus_visitados) as promedio_menus
FROM v_sesiones_diarias 
WHERE tipo_llamada = 'OFICIAL'

UNION ALL

SELECT 
    'DERIVADO' as tipo,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos, 
    AVG(total_interacciones) as promedio_interacciones,
    AVG(menus_visitados) as promedio_menus
FROM v_sesiones_diarias
WHERE tipo_llamada = 'DERIVADO';
```

#### **Hipótesis 2: Números Internos/Prueba**
```sql
-- ¿Patrones de testing o uso interno?
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(DISTINCT fecha) as dias_activos,
    AVG(total_interacciones) as interacciones_promedio,
    patron_comportamiento,
    opciones_usadas
FROM v_analisis_derivados
WHERE patron_comportamiento IN ('POSIBLE_INTERNO', 'AUTOMATICO', 'ALTO_VOLUMEN')
ORDER BY dias_activos DESC;
```

#### **Hipótesis 3: Funcionalidad del Sistema**
```sql
-- ¿Tienen acceso a opciones válidas del menú?
SELECT 
    tipo_llamada,
    menu,
    opcion,
    COUNT(*) as frecuencia_uso,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    AVG(TIME_TO_SEC(hora_fin_real) - TIME_TO_SEC(hora_inicio_real)) as duracion_promedio
FROM v_interacciones_limpias
GROUP BY tipo_llamada, menu, opcion
ORDER BY tipo_llamada, frecuencia_uso DESC;
```

---

## 📊 **Estrategia de Decisión**

### **Matriz de Decisión: ¿Incluir DERIVADOS en el promedio?**

| Escenario | Criterio | Decisión |
|-----------|----------|----------|
| **DERIVADOS < 10% del total** | Poco impacto | ✅ Reportar solo OFICIALES |
| **DERIVADOS tienen comportamiento similar** | Usuarios válidos | ✅ Incluir ambos tipos |
| **DERIVADOS son números internos/prueba** | Contaminan métricas | ❌ Excluir del reporte |
| **DERIVADOS son transferencias legítimas** | Parte del journey | ✅ Reportar por separado |

### **Implementación de la Decisión**
```sql
-- REPORTE FINAL CONFIGURÁVEL
SELECT 
    fecha,
    
    -- Reporte base (solo oficiales)
    promedio_interacciones_por_usuario as promedio_oficial,
    usuarios_activos as usuarios_oficiales,
    
    -- Reporte extendido (si se requiere)
    (SELECT promedio_interacciones_por_usuario 
     FROM v_reporte_diario rd2 
     WHERE rd2.fecha = rd1.fecha AND rd2.tipo_llamada = 'DERIVADO') as promedio_derivado,
     
    (SELECT usuarios_activos 
     FROM v_reporte_diario rd3 
     WHERE rd3.fecha = rd1.fecha AND rd3.tipo_llamada = 'DERIVADO') as usuarios_derivados
     
FROM v_reporte_diario rd1
WHERE tipo_llamada = 'OFICIAL'
ORDER BY fecha;
```

---

## 🚀 **Plan de Implementación**

### **Fase 1: Validación (Semana 1)**
1. **Ejecutar queries de exploración** → Cuantificar problemas de calidad
2. **Analizar comportamiento DERIVADOS** → Decidir estrategia de inclusión/exclusión  
3. **Validar lógica de timestamps** → Confirmar corrección de invertidos
4. **Prototipo reporte diario** → Validar con stakeholders

### **Fase 2: Construcción (Semana 2)**
1. **Crear vistas optimizadas** para MariaDB 10.1
2. **Implementar reportes temporales** (diario → semanal → mensual → anual)
3. **Documentar decisiones** sobre DERIVADOS
4. **Testing de performance** con volúmenes reales

### **Fase 3: Automatización (Semana 3)**
1. **Stored procedures** para generación automática
2. **Scheduling** de reportes periódicos
3. **Alertas** para anomalías en los promedios
4. **Dashboard** básico (opcional)

---

## ❓ **Preguntas Críticas para Stakeholders**

### **Definición de Negocio**
1. **¿Una "interacción exitosa" requiere llegar a un menú/opción específica?**
2. **¿Los DERIVADOS representan transferencias legítimas o ruido en los datos?**
3. **¿Hay horarios específicos donde filtrar las interacciones?**

### **Contexto Organizacional**  
4. **¿El análisis debe segmentarse por división/área desde el inicio?**
5. **¿Qué nivel de granularidad se requiere? (solo promedios o distribuciones completas)**
6. **¿Hay números específicos que siempre se deben excluir?**

---

## 🎯 **Entregables Esperados**

### **Reporte Principal (Con Dimensión Trimestral)**
```
Trimestre | Fecha      | Grupo_Zonas | Usuarios Activos | Interacciones Totales | Promedio por Usuario
Q01_25    | 2025-02-15 | Z001        | 1,247           | 3,891                | 3.12
Q01_25    | 2025-02-16 | Z001        | 1,338           | 4,201                | 3.14  
Q02_25    | 2025-04-15 | Z001        | 1,156           | 3,567                | 3.08
Q02_25    | 2025-04-15 | Z002        | 892             | 2,845                | 3.19
```

### **Reportes Evolutivos (Con Contexto Trimestral)**
- **Trimestral**: Comparativo directo Q01 vs Q02 vs Q03 por zona
- **Semanal**: Promedio semanal dentro de cada trimestre  
- **Mensual**: Tendencia mensual con solapamiento trimestral
- **Anual**: Vista ejecutiva consolidada por trimestre

### **Análisis de Insights**
- **Patrones de comportamiento** por tipo de llamada
- **Eficiencia del sistema** (journey length, tiempo promedio)
- **Recomendaciones** basadas en análisis de DERIVADOS

---

**🚀 ¿Proceder con la implementación siguiendo esta arquitectura conceptual?**