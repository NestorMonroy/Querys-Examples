# AS-IS: Identificación y Mapeo del Modelo de Datos

## Objetivo
Entender la estructura, relaciones y significado de los datos antes de realizar cualquier análisis de comportamiento.

---

## 1. Inventario de Campos y Tipología

### **Campos Identificados en las 3 Tablas:**
```
llamadas_Q1, llamadas_Q2, llamadas_Q3 (estructura idéntica)
├── idRe (ID único del registro)
├── numero_entrada (Número iniciador)
├── numero_digitado (Número procesado/destino)
├── menu (Menú del sistema)
├── opcion (Opción seleccionada)
├── id_CTransferencia (Destino de redirección)
├── fecha (Fecha de la interacción)
├── division (División organizacional)
├── area (Área específica)
├── hora_inicio (Hora inicio interacción)
├── hora_fin (Hora fin interacción)
├── id_8T (Grupo zonas geográficas)
├── etiquetas (Metadatos del procesamiento)
├── cIdentifica (Clave para joins externos)
├── fecha_inserta (Timestamp de inserción)
└── nidMQ (Relacionado con numero_digitado)
```

---

## 2. Análisis de Estructura de Datos

### **Query Base para Identificación:**
```sql
-- ESTRUCTURA Y CARDINALIDAD POR TRIMESTRE
SELECT 
    'llamadas_Q1' as tabla,
    COUNT(*) as total_registros,
    COUNT(DISTINCT idRe) as ids_unicos,
    COUNT(DISTINCT numero_entrada) as numeros_entrada_unicos,
    COUNT(DISTINCT numero_digitado) as numeros_digitado_unicos,
    COUNT(DISTINCT menu) as menus_diferentes,
    COUNT(DISTINCT opcion) as opciones_diferentes,
    COUNT(DISTINCT id_CTransferencia) as destinos_transferencia_unicos,
    COUNT(DISTINCT id_8T) as zonas_geograficas,
    COUNT(DISTINCT division) as divisiones,
    COUNT(DISTINCT area) as areas,
    COUNT(DISTINCT cIdentifica) as claves_cIdentifica,
    MIN(fecha) as fecha_minima,
    MAX(fecha) as fecha_maxima
FROM llamadas_Q1

UNION ALL

SELECT 
    'llamadas_Q2' as tabla,
    COUNT(*), COUNT(DISTINCT idRe), COUNT(DISTINCT numero_entrada),
    COUNT(DISTINCT numero_digitado), COUNT(DISTINCT menu), COUNT(DISTINCT opcion),
    COUNT(DISTINCT id_CTransferencia), COUNT(DISTINCT id_8T), COUNT(DISTINCT division),
    COUNT(DISTINCT area), COUNT(DISTINCT cIdentifica), MIN(fecha), MAX(fecha)
FROM llamadas_Q2

UNION ALL

SELECT 
    'llamadas_Q3' as tabla,
    COUNT(*), COUNT(DISTINCT idRe), COUNT(DISTINCT numero_entrada),
    COUNT(DISTINCT numero_digitado), COUNT(DISTINCT menu), COUNT(DISTINCT opcion),
    COUNT(DISTINCT id_CTransferencia), COUNT(DISTINCT id_8T), COUNT(DISTINCT division),
    COUNT(DISTINCT area), COUNT(DISTINCT cIdentifica), MIN(fecha), MAX(fecha)
FROM llamadas_Q3;
```

### **Análisis de Completitud de Datos:**
```sql
-- ANÁLISIS DE CAMPOS NULOS/VACÍOS
SELECT 
    'numero_entrada' as campo,
    SUM(CASE WHEN numero_entrada IS NULL OR numero_entrada = '' THEN 1 ELSE 0 END) as nulos_vacios,
    COUNT(*) as total,
    ROUND(SUM(CASE WHEN numero_entrada IS NULL OR numero_entrada = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as porcentaje_nulos
FROM llamadas_Q1

UNION ALL

SELECT 'numero_digitado', SUM(CASE WHEN numero_digitado IS NULL OR numero_digitado = '' THEN 1 ELSE 0 END), COUNT(*),
       ROUND(SUM(CASE WHEN numero_digitado IS NULL OR numero_digitado = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM llamadas_Q1

UNION ALL

SELECT 'menu', SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END), COUNT(*),
       ROUND(SUM(CASE WHEN menu IS NULL OR menu = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM llamadas_Q1

UNION ALL

SELECT 'opcion', SUM(CASE WHEN opcion IS NULL OR opcion = '' THEN 1 ELSE 0 END), COUNT(*),
       ROUND(SUM(CASE WHEN opcion IS NULL OR opcion = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM llamadas_Q1

UNION ALL

SELECT 'id_CTransferencia', SUM(CASE WHEN id_CTransferencia IS NULL OR id_CTransferencia = '' THEN 1 ELSE 0 END), COUNT(*),
       ROUND(SUM(CASE WHEN id_CTransferencia IS NULL OR id_CTransferencia = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM llamadas_Q1

UNION ALL

SELECT 'etiquetas', SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END), COUNT(*),
       ROUND(SUM(CASE WHEN etiquetas IS NULL OR etiquetas = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM llamadas_Q1

UNION ALL

SELECT 'division', SUM(CASE WHEN division IS NULL OR division = '' THEN 1 ELSE 0 END), COUNT(*),
       ROUND(SUM(CASE WHEN division IS NULL OR division = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM llamadas_Q1

UNION ALL

SELECT 'area', SUM(CASE WHEN area IS NULL OR area = '' THEN 1 ELSE 0 END), COUNT(*),
       ROUND(SUM(CASE WHEN area IS NULL OR area = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM llamadas_Q1

UNION ALL

SELECT 'cIdentifica', SUM(CASE WHEN cIdentifica IS NULL OR cIdentifica = '' THEN 1 ELSE 0 END), COUNT(*),
       ROUND(SUM(CASE WHEN cIdentifica IS NULL OR cIdentifica = '' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM llamadas_Q1;
```

---

## 3. Análisis de Dominios de Valores

### **Catálogo de Valores Únicos:**
```sql
-- DOMINIO DE VALORES - MENÚS
SELECT 
    'menu' as tipo_campo,
    menu as valor,
    COUNT(*) as frecuencia,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje
FROM llamadas_Q1
WHERE menu IS NOT NULL AND menu != ''
GROUP BY menu
ORDER BY frecuencia DESC
LIMIT 20;

-- DOMINIO DE VALORES - OPCIONES
SELECT 
    'opcion' as tipo_campo,
    opcion as valor,
    COUNT(*) as frecuencia,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje
FROM llamadas_Q1
WHERE opcion IS NOT NULL AND opcion != ''
GROUP BY opcion
ORDER BY frecuencia DESC
LIMIT 20;

-- DOMINIO DE VALORES - DIVISIONES
SELECT 
    'division' as tipo_campo,
    division as valor,
    COUNT(*) as frecuencia,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje
FROM llamadas_Q1
WHERE division IS NOT NULL AND division != ''
GROUP BY division
ORDER BY frecuencia DESC;

-- DOMINIO DE VALORES - ZONAS GEOGRÁFICAS
SELECT 
    'id_8T' as tipo_campo,
    id_8T as valor,
    COUNT(*) as frecuencia,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje
FROM llamadas_Q1
WHERE id_8T IS NOT NULL AND id_8T != ''
GROUP BY id_8T
ORDER BY frecuencia DESC;
```

---

## 4. Análisis de Relaciones entre Campos

### **Identificación de Dependencias:**
```sql
-- RELACIÓN: division → area
SELECT 
    division,
    COUNT(DISTINCT area) as areas_por_division,
    GROUP_CONCAT(DISTINCT area ORDER BY area) as areas_listado
FROM llamadas_Q1
WHERE division IS NOT NULL AND area IS NOT NULL
GROUP BY division
ORDER BY division;

-- RELACIÓN: menu → opcion (cardinalidad)
SELECT 
    menu,
    COUNT(DISTINCT opcion) as opciones_por_menu,
    COUNT(*) as total_usos,
    GROUP_CONCAT(DISTINCT opcion ORDER BY opcion) as opciones_disponibles
FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu
ORDER BY total_usos DESC
LIMIT 15;

-- RELACIÓN: id_8T → division/area
SELECT 
    id_8T,
    COUNT(DISTINCT division) as divisiones_por_zona,
    COUNT(DISTINCT area) as areas_por_zona,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) ORDER BY division) as ubicaciones
FROM llamadas_Q1
WHERE id_8T IS NOT NULL AND division IS NOT NULL
GROUP BY id_8T
ORDER BY id_8T;
```

### **Análisis de Claves y Unicidad:**
```sql
-- ¿idRe es realmente único?
SELECT 
    'idRe_duplicados' as analisis,
    COUNT(*) - COUNT(DISTINCT idRe) as registros_duplicados
FROM llamadas_Q1

UNION ALL

-- ¿Hay superposición de idRe entre trimestres?
SELECT 
    'idRe_entre_trimestres' as analisis,
    COUNT(*) as coincidencias
FROM llamadas_Q1 q1
INNER JOIN llamadas_Q2 q2 ON q1.idRe = q2.idRe

UNION ALL

-- ¿numero_entrada puede tener múltiples numero_digitado?
SELECT 
    'numero_entrada_cardinalidad' as analisis,
    COUNT(*) as casos_multiples
FROM (
    SELECT numero_entrada, COUNT(DISTINCT numero_digitado) as destinos
    FROM llamadas_Q1
    WHERE numero_entrada IS NOT NULL AND numero_digitado IS NOT NULL
    GROUP BY numero_entrada
    HAVING COUNT(DISTINCT numero_digitado) > 1
) sub;
```

---

## 5. Análisis de Patrones Temporales en Datos

### **Distribución Temporal:**
```sql
-- DISTRIBUCIÓN POR FECHA
SELECT 
    fecha,
    COUNT(*) as registros_por_dia,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos_dia,
    MIN(hora_inicio) as primera_hora,
    MAX(hora_fin) as ultima_hora,
    COUNT(DISTINCT menu) as menus_activos_dia
FROM llamadas_Q1
GROUP BY fecha
ORDER BY fecha;

-- ANÁLISIS DE INCONSISTENCIAS TEMPORALES
SELECT 
    'timestamps_invertidos' as problema,
    COUNT(*) as casos,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje
FROM llamadas_Q1
WHERE hora_fin < hora_inicio

UNION ALL

SELECT 
    'fecha_vs_fecha_inserta' as problema,
    COUNT(*) as casos,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje
FROM llamadas_Q1
WHERE DATE(STR_TO_DATE(fecha, '%d/%m/%Y')) != DATE(STR_TO_DATE(fecha_inserta, '%d/%m/%Y %H:%i:%s'));
```

---

## 6. Análisis de Referencias Externas

### **Campos de Referencia:**
```sql
-- ANÁLISIS DE cIdentifica (clave para otras tablas)
SELECT 
    'cIdentifica_patron' as analisis,
    LEFT(cIdentifica, 10) as patron_inicio,
    COUNT(*) as frecuencia,
    COUNT(DISTINCT numero_entrada) as usuarios_con_patron
FROM llamadas_Q1
WHERE cIdentifica IS NOT NULL AND cIdentifica != ''
GROUP BY LEFT(cIdentifica, 10)
ORDER BY frecuencia DESC
LIMIT 10;

-- ANÁLISIS DE nidMQ
SELECT 
    'nidMQ_vs_numero_digitado' as analisis,
    COUNT(*) as total_registros,
    SUM(CASE WHEN nidMQ IS NOT NULL AND nidMQ != '' THEN 1 ELSE 0 END) as con_nidMQ,
    SUM(CASE WHEN numero_digitado IS NOT NULL AND numero_digitado != '' THEN 1 ELSE 0 END) as con_numero_digitado,
    SUM(CASE WHEN nidMQ IS NOT NULL AND numero_digitado IS NOT NULL 
             AND nidMQ LIKE CONCAT('%', numero_digitado, '%') THEN 1 ELSE 0 END) as nidMQ_contiene_numero_digitado
FROM llamadas_Q1;
```

---

## 7. Modelo de Datos Inferido

### **Entidades Identificadas:**

#### **Entidad Principal: INTERACCION**
- **Clave primaria**: `idRe`
- **Timestamp**: `fecha + hora_inicio/hora_fin`
- **Usuario**: `numero_entrada`
- **Proceso**: `numero_digitado`

#### **Entidad: NAVEGACION**
- **Menú**: `menu`
- **Opción**: `opcion`
- **Resultado**: `etiquetas`

#### **Entidad: UBICACION_ORGANIZACIONAL**
- **Zona geográfica**: `id_8T`
- **División**: `division`  
- **Área**: `area`

#### **Entidad: REDIRECCIÓN**
- **Destino**: `id_CTransferencia`
- **Referencia externa**: `cIdentifica`

### **Relaciones Inferidas:**
```
INTERACCION 1:1 NAVEGACION
INTERACCION N:1 UBICACION_ORGANIZACIONAL  
INTERACCION 0:1 REDIRECCIÓN
INTERACCION 0:1 REFERENCIA_EXTERNA (cIdentifica)
```

### **Dependencias Funcionales Detectadas:**
```
division → {conjunto_de_areas}
menu → {conjunto_de_opciones}
menu + opcion → {patron_etiquetas}
id_8T → {division, area} (parcial)
```

---

## 8. Identificación de Problemas de Calidad

### **Problemas Detectados:**
1. **Timestamps invertidos**: `hora_fin < hora_inicio`
2. **Fechas inconsistentes**: `fecha != DATE(fecha_inserta)`  
3. **Campos relacionados nulos**: `numero_digitado` nulo pero `nidMQ` con valor
4. **Etiquetas inconsistentes**: No siguen patrón esperado según `menu+opcion`

### **Query de Diagnóstico Integral:**
```sql
-- REPORTE DE CALIDAD DE DATOS
SELECT 
    COUNT(*) as total_registros,
    
    -- Integridad referencial
    SUM(CASE WHEN numero_entrada IS NULL THEN 1 ELSE 0 END) as sin_numero_entrada,
    SUM(CASE WHEN menu IS NULL THEN 1 ELSE 0 END) as sin_menu,
    
    -- Consistencia temporal  
    SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) as timestamps_invertidos,
    
    -- Consistencia de procesamiento
    SUM(CASE WHEN numero_digitado IS NULL AND nidMQ IS NOT NULL THEN 1 ELSE 0 END) as inconsistencia_digitado_nidMQ,
    
    -- Completitud organizacional
    SUM(CASE WHEN division IS NULL AND area IS NOT NULL THEN 1 ELSE 0 END) as area_sin_division,
    
    -- Referencias externas
    SUM(CASE WHEN cIdentifica IS NOT NULL AND cIdentifica != '' THEN 1 ELSE 0 END) as con_referencias_externas,
    
    -- Cálculo de score de calidad
    ROUND((COUNT(*) - SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) 
           - SUM(CASE WHEN numero_entrada IS NULL THEN 1 ELSE 0 END)
           - SUM(CASE WHEN menu IS NULL THEN 1 ELSE 0 END)) * 100.0 / COUNT(*), 2) as score_calidad_pct

FROM llamadas_Q1;
```

---

## Conclusiones del Modelo de Datos

### **Estructura Confirmada:**
- Tabla de interacciones con sistema de menús
- Particionamiento temporal por trimestres
- Múltiples dimensiones: temporal, geográfica, organizacional, funcional

### **Campos Clave para Análisis:**
- **Comportamiento**: `numero_entrada + fecha + menu + opcion`
- **Validación**: `etiquetas`  
- **Redirección**: `id_CTransferencia`
- **Referencias**: `cIdentifica`

### **Limitaciones Actuales:**
- Acceso pendiente a tablas relacionadas vía `cIdentifica`
- Calidad de datos variable (timestamps, nulos)
- Significado exacto de algunos códigos pendiente de validación

Este modelo de datos AS-IS debe validarse antes de proceder con análisis de comportamiento o reportes de KPIs.