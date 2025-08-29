# 🎯 **Solución Conceptual AS-IS: Sistema de Reportes por Trimestres**

## 🧠 **Entendimiento del Problema**

### **¿Qué me están pidiendo exactamente?**
- **Reporte Principal**: Promedio de interacciones que tiene cada `numero_entrada` por día
- **Evolución Temporal**: Expandir a semana, mes, año
- **Estructura de Datos**: Por TRIMESTRES con fechas específicas ya definidas
- **Problema de Datos**: `numero_entrada` ≠ `numero_digitado` (¿son válidos? ¿qué significan?)
- **Calidad**: Timestamps invertidos que necesitan corrección

### **Estructura Temporal Definida:**
```sql
-- Variables ya establecidas
SET @Q1_nombre = 'Q01_25';
SET @Q1_inicio = '2025-02-01'; 
SET @Q1_fin = '2025-03-31';    -- 59 días

SET @Q2_nombre = 'Q02_25';
SET @Q2_inicio = '2025-04-01';
SET @Q2_fin = '2025-06-30';    -- 91 días

SET @Q3_nombre = 'Q03_25';  
SET @Q3_inicio = '2025-07-01';
SET @Q3_fin = '2025-07-31';    -- 31 días (¿período incompleto?)
```

### **¿Qué representa conceptualmente cada elemento?**
- **`numero_entrada`** = Usuario/Cliente que inicia la interacción
- **`numero_digitado`** = ¿Destino? ¿Número procesado? ¿Enrutamiento?
- **`id_8T`** = Grupo de zonas geográficas (dimensión territorial)
- **Un registro** = Una acción/decisión en el menú del sistema
- **Múltiples registros por día** = Journey completo del usuario
- **Trimestre** = Unidad de análisis temporal y particionamiento de datos

---

## 📋 **Análisis AS-IS: Contexto por Trimestres**

### **Datos Disponibles por Período:**
```
Q01_25: llamadas_Q1 (Feb-Mar 2025) = 59 días hábiles
Q02_25: llamadas_Q2 (Abr-Jun 2025) = 91 días hábiles  
Q03_25: llamadas_Q3 (Jul 2025)     = 31 días hábiles
```

### **Consideraciones Temporales AS-IS:**
- **Q1**: Período completo (Feb-Mar) = Base de comparación
- **Q2**: Período completo (Abr-Jun) = Comparativo estacional  
- **Q3**: **¿Período parcial?** (Solo Julio) = Validar si está completo

### **Preguntas AS-IS Inmediatas:**
1. **¿Q3 está completo o aún capturando datos?**
2. **¿Los rangos de fechas reflejan períodos operativos reales?**
3. **¿Hay estacionalidad conocida entre trimestres?**
4. **¿Los promedios deben calcularse por zona (`id_8T`) o globales?**

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

## 🏗️ **Arquitectura de Solución AS-IS**

### **Capa 1: Exploración Inicial (SIN LIMPIAR AÚN)**

#### **A. Análisis de Contexto por Trimestre**
```sql
-- CONCEPTO: Entender el landscape ANTES de limpiar
SELECT 
    'Q1_2025' as trimestre,
    @Q1_inicio as fecha_inicio,
    @Q1_fin as fecha_fin,
    COUNT(*) as total_registros,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    COUNT(DISTINCT DATE(fecha)) as dias_con_datos,
    COUNT(DISTINCT id_8T) as zonas_activas,
    
    -- Problemas de calidad SIN corregir aún
    SUM(CASE WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 THEN 1 ELSE 0 END) as timestamps_invertidos,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as llamadas_derivadas,
    
    -- Porcentajes de problemas
    ROUND(SUM(CASE WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_timestamps_mal,
    ROUND(SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_derivadas
    
FROM llamadas_Q1
WHERE fecha BETWEEN @Q1_inicio AND @Q1_fin

UNION ALL

SELECT 
    'Q2_2025' as trimestre,
    @Q2_inicio as fecha_inicio,
    @Q2_fin as fecha_fin,
    COUNT(*) as total_registros,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    COUNT(DISTINCT DATE(fecha)) as dias_con_datos,
    COUNT(DISTINCT id_8T) as zonas_activas,
    
    SUM(CASE WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 THEN 1 ELSE 0 END) as timestamps_invertidos,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as llamadas_derivadas,
    
    ROUND(SUM(CASE WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_timestamps_mal,
    ROUND(SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_derivadas
    
FROM llamadas_Q2
WHERE fecha BETWEEN @Q2_inicio AND @Q2_fin

UNION ALL

SELECT 
    'Q3_2025' as trimestre,
    @Q3_inicio as fecha_inicio,
    @Q3_fin as fecha_fin,
    COUNT(*) as total_registros,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    COUNT(DISTINCT DATE(fecha)) as dias_con_datos,
    COUNT(DISTINCT id_8T) as zonas_activas,
    
    SUM(CASE WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 THEN 1 ELSE 0 END) as timestamps_invertidos,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as llamadas_derivadas,
    
    ROUND(SUM(CASE WHEN TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio) < 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_timestamps_mal,
    ROUND(SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_derivadas
    
FROM llamadas_Q3
WHERE fecha BETWEEN @Q3_inicio AND @Q3_fin;
```

#### **B. Investigación Comportamiento DERIVADAS (Por Trimestre)**
```sql
-- CONCEPTO: ¿Qué sucede cuando numero_entrada ≠ numero_digitado?
SELECT 
    'Q1_2025' as trimestre,
    numero_entrada,
    numero_digitado,
    id_8T as zona,
    COUNT(*) as frecuencia_uso,
    COUNT(DISTINCT DATE(fecha)) as dias_activos,
    AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)) as duracion_promedio_seg,
    
    -- ¿Qué opciones usan?
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion)) as opciones_usadas,
    
    -- ¿Patrón sospechoso?
    CASE 
        WHEN COUNT(DISTINCT DATE(fecha)) > 20 THEN 'POSIBLE_INTERNO'
        WHEN AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)) < 5 THEN 'AUTOMATICO'
        WHEN COUNT(*) / COUNT(DISTINCT DATE(fecha)) > 15 THEN 'ALTO_VOLUMEN'
        ELSE 'NORMAL'
    END as patron_comportamiento
    
FROM llamadas_Q1
WHERE numero_entrada != numero_digitado
  AND fecha BETWEEN @Q1_inicio AND @Q1_fin
GROUP BY numero_entrada, numero_digitado, id_8T
ORDER BY frecuencia_uso DESC
LIMIT 20;

-- REPETIR PARA Q2 y Q3
```

#### **C. Análisis de Zonas Geográficas (Dimensión Clave)**
```sql
-- CONCEPTO: ¿Hay diferencias significativas por zona (id_8T)?
SELECT 
    id_8T as zona,
    COUNT(*) as total_interacciones,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    COUNT(DISTINCT DATE(fecha)) as dias_activos,
    
    -- Promedio BRUTO por zona (sin limpiar aún)
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada) / COUNT(DISTINCT DATE(fecha)), 2) as promedio_bruto_diario,
    
    -- Distribución oficial vs derivada
    SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) as oficiales,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as derivadas,
    ROUND(SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_oficiales
    
FROM (
    SELECT * FROM llamadas_Q1 WHERE fecha BETWEEN @Q1_inicio AND @Q1_fin
    UNION ALL
    SELECT * FROM llamadas_Q2 WHERE fecha BETWEEN @Q2_inicio AND @Q2_fin
    UNION ALL  
    SELECT * FROM llamadas_Q3 WHERE fecha BETWEEN @Q3_inicio AND @Q3_fin
) todas_llamadas
GROUP BY id_8T
ORDER BY total_interacciones DESC;
```

---

## 🔬 **Investigación: numero_entrada ≠ numero_digitado**

### **Hipótesis a Validar (Enfoque AS-IS)**

#### **Hipótesis 1: Enrutamiento Inteligente por Zona**
```sql
-- ¿Las derivadas siguen patrones geográficos?
SELECT 
    id_8T as zona,
    'OFICIAL' as tipo,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    AVG(COUNT(*)) as promedio_interacciones_raw
FROM todas_llamadas 
WHERE numero_entrada = numero_digitado
GROUP BY id_8T

UNION ALL

SELECT 
    id_8T as zona,
    'DERIVADO' as tipo,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    AVG(COUNT(*)) as promedio_interacciones_raw
FROM todas_llamadas
WHERE numero_entrada != numero_digitado
GROUP BY id_8T
ORDER BY zona, tipo;
```

#### **Hipótesis 2: Comportamiento Temporal**
```sql
-- ¿Las derivadas varían por trimestre?
SELECT 
    CASE 
        WHEN fecha BETWEEN @Q1_inicio AND @Q1_fin THEN 'Q1_2025'
        WHEN fecha BETWEEN @Q2_inicio AND @Q2_fin THEN 'Q2_2025' 
        WHEN fecha BETWEEN @Q3_inicio AND @Q3_fin THEN 'Q3_2025'
    END as trimestre,
    
    SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) as oficiales,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as derivadas,
    
    ROUND(SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pct_derivadas
    
FROM todas_llamadas
GROUP BY trimestre
ORDER BY trimestre;
```

#### **Hipótesis 3: Acceso a Menús Válidos**
```sql
-- ¿Las derivadas usan los mismos menús/opciones que las oficiales?
SELECT 
    CASE WHEN numero_entrada = numero_digitado THEN 'OFICIAL' ELSE 'DERIVADO' END as tipo_llamada,
    menu,
    opcion,
    COUNT(*) as frecuencia,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    AVG(TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)) as duracion_promedio
FROM todas_llamadas
WHERE menu IS NOT NULL AND opcion IS NOT NULL
GROUP BY tipo_llamada, menu, opcion
ORDER BY tipo_llamada, frecuencia DESC;
```

---

## 📊 **Estrategia de Decisión AS-IS**

### **Matriz de Decisión: ¿Incluir DERIVADOS en el promedio?**

| Escenario Descubierto | Criterio AS-IS | Decisión |
|----------------------|----------------|----------|
| **DERIVADOS < 10% total** | Poco impacto estadístico | ✅ Reportar solo OFICIALES |
| **DERIVADOS comportamiento similar** | Usuarios legítimos | ✅ Incluir ambos tipos |
| **DERIVADOS concentrados en 1-2 zonas** | Patrón geográfico específico | 🔄 Reportar segmentado por zona |
| **DERIVADOS = números con prefijo/patrón** | Testing/internos identificables | ❌ Excluir del reporte |
| **DERIVADOS usan mismos menús** | Funcionalidad válida | ✅ Reportar por separado |
| **DERIVADOS solo en Q3** | Cambio de sistema reciente | 🔄 Nota metodológica en reporte |

---

## 🎯 **Plan de Ejecución AS-IS**

### **Fase 1: Exploración Inmediata (Esta Semana)**

#### **Día 1-2: Reconnaissance Trimestral**
1. **Ejecutar Query A** → Volúmenes y calidad por trimestre
2. **Validar Q3** → ¿Está completo o parcial?
3. **Identificar zonas dominantes** → ¿Alguna zona representa >50% del volumen?

#### **Día 3-4: Investigación DERIVADOS**
1. **Ejecutar Query B** → Patrones de comportamiento DERIVADOS
2. **Análisis por zona** → ¿Concentración geográfica?
3. **Análisis temporal** → ¿Variación por trimestre?

#### **Día 5: Decision Point**
1. **Consolidar hallazgos** → ¿Limpiar masivamente o selectivamente?
2. **Definir estrategia DERIVADOS** → ¿Incluir, excluir, o segmentar?
3. **Validar con stakeholders** → ¿Las hipótesis son correctas?

### **Fase 2: Implementación (Próxima Semana)**
1. **Vista de limpieza** basada en hallazgos AS-IS
2. **Reporte prototipo** con decisiones validadas
3. **Testing con datos reales** de cada trimestre

### **Fase 3: Productivización (Tercera Semana)**
1. **Optimización MariaDB 10.1** con volúmenes reales
2. **Automatización** de reportes periódicos
3. **Documentación** de decisiones metodológicas

---

## ❓ **Preguntas Críticas AS-IS para Stakeholders**

### **Contexto Temporal**
1. **¿Q3 está completo o continuará creciendo?**
2. **¿Los trimestres reflejan períodos operativos naturales?**
3. **¿Hay estacionalidad esperada entre Q1, Q2, Q3?**

### **Dimensión Geográfica**
4. **¿Los promedios deben calcularse por zona (`id_8T`) o globales?**
5. **¿Hay zonas con características operativas diferentes?**
6. **¿Alguna zona debe excluirse del análisis (testing, etc.)?**

### **Comportamiento DERIVADOS**
7. **¿Qué representa conceptualmente `numero_digitado` cuando difiere?**
8. **¿Es posible que sean transferencias legítimas del sistema?**
9. **¿Hay números conocidos que siempre generan derivados?**

---

## 🎯 **Entregables Esperados (Con Dimensión Trimestral)**

### **Reporte Principal AS-IS**
```
Trimestre | Fecha      | Zona | Usuarios Activos | Interacciones Totales | Promedio por Usuario
Q01_25    | 2025-02-15 | Z001 | 1,247           | 3,891                | 3.12
Q01_25    | 2025-02-15 | Z002 | 892             | 2,845                | 3.19
Q02_25    | 2025-04-15 | Z001 | 1,156           | 3,567                | 3.08
Q03_25    | 2025-07-15 | Z001 | 1,089           | 3,401                | 3.13
```

### **Análisis de Comportamiento DERIVADOS**
- **Distribución por trimestre** y zona
- **Patrones de uso** (menús/opciones frecuentes)  
- **Recomendación** sobre inclusión en promedios

### **Insights Trimestrales**
- **Comparativo Q1 vs Q2 vs Q3** (considerando días disponibles)
- **Variaciones por zona geográfica**
- **Evolución temporal** con proyecciones

---

**🚀 ¿Empezamos con el análisis AS-IS trimestral para entender el contexto real antes de cualquier limpieza?**