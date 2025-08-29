# AS-IS Corregido: Análisis de Datos sin Errores Conceptuales

## Campos y su Interpretación Correcta

### **Campos de Redirección/Transferencia Real:**
- **`id_CTransferencia`**: Destino real de redirección del sistema
- **`cIdentifica`**: Clave para joins con otras tablas (acceso pendiente)

### **Campos de Procesamiento Interno:**
- **`numero_entrada`**: Número que inicia la interacción
- **`numero_digitado`**: Número procesado internamente (puede diferir por lógica de negocio)

### **Diferencia Conceptual:**
- `numero_entrada ≠ numero_digitado` = Procesamiento interno, NO transferencia
- `id_CTransferencia` con valor = Redirección real del sistema

---

## Análisis AS-IS Corregidos

### **1. Análisis de Journey de Usuario (Corregido)**

```sql
-- CONCEPTO: Reconstruir journey sin asumir transferencias incorrectas
SELECT 
    numero_entrada,
    fecha,
    COUNT(*) as total_interacciones,
    
    -- Journey temporal reconstruido
    GROUP_CONCAT(
        CONCAT(
            TIME_FORMAT(
                CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END, 
                '%H:%i'
            ), 
            ':[', COALESCE(menu, 'SIN_MENU'), '-', COALESCE(opcion, 'SIN_OPCION'), ']'
        ) 
        ORDER BY CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END
        SEPARATOR ' → '
    ) as patron_navegacion,
    
    -- Análisis de redirecciones REALES
    COUNT(DISTINCT id_CTransferencia) as redirecciones_diferentes,
    GROUP_CONCAT(DISTINCT id_CTransferencia) as destinos_redireccion,
    
    -- Análisis de procesamiento interno (sin asumir transferencia)
    COUNT(DISTINCT numero_digitado) as numeros_procesados_diferentes,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as casos_procesamiento_interno,
    
    -- Análisis de etiquetas
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_sesion
    
FROM llamadas_Q1
WHERE numero_entrada IS NOT NULL
GROUP BY numero_entrada, fecha
ORDER BY numero_entrada, fecha;
```

### **2. Análisis de Redirecciones del Sistema (Corregido)**

```sql
-- CONCEPTO: Usar el campo correcto para analizar redirecciones
SELECT 
    id_CTransferencia,
    COUNT(*) as frecuencia_redireccion,
    COUNT(DISTINCT numero_entrada) as usuarios_redirigidos,
    
    -- Contexto de redirecciones
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menus_que_redirigen,
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as contexto_organizacional,
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR ' | ') as patron_etiquetas,
    
    -- Análisis temporal
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_redireccion,
    MAX(fecha) as ultima_redireccion,
    
    -- Casos con procesamiento interno simultáneo
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as casos_con_procesamiento_interno,
    
    -- Referencias para joins futuros
    COUNT(DISTINCT cIdentifica) as referencias_cIdentifica
    
FROM llamadas_Q1
WHERE id_CTransferencia IS NOT NULL 
  AND id_CTransferencia != ''
GROUP BY id_CTransferencia
ORDER BY frecuencia_redireccion DESC
LIMIT 20;
```

### **3. Análisis de Procesamiento Interno (Nuevo)**

```sql
-- CONCEPTO: Entender cuándo numero_entrada ≠ numero_digitado (SIN asumir transferencia)
SELECT 
    'NUMEROS_IGUALES' as tipo_procesamiento,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_frecuentes,
    SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as con_redireccion_real
FROM llamadas_Q1 
WHERE numero_entrada = numero_digitado

UNION ALL

SELECT 
    'NUMEROS_DIFERENTES' as tipo_procesamiento,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_frecuentes,
    SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as con_redireccion_real
FROM llamadas_Q1 
WHERE numero_entrada != numero_digitado

UNION ALL

SELECT 
    'NUMERO_DIGITADO_NULO' as tipo_procesamiento,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_frecuentes,
    SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as con_redireccion_real
FROM llamadas_Q1 
WHERE numero_digitado IS NULL OR numero_digitado = '';
```

### **4. Análisis de Eficiencia de Menús (Corregido)**

```sql
-- CONCEPTO: Eficiencia sin confundir procesamiento interno con transferencias
SELECT 
    menu,
    opcion,
    COUNT(*) as total_usos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- Análisis de efectividad (usando etiquetas como indicador)
    SUM(CASE WHEN etiquetas LIKE '%VSI%' OR etiquetas LIKE '%ZMB%' THEN 1 ELSE 0 END) as interacciones_validadas,
    SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas,
    
    -- Tasa de validación (no "éxito" que puede ser ambiguo)
    ROUND(
        SUM(CASE WHEN etiquetas LIKE '%VSI%' OR etiquetas LIKE '%ZMB%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) as tasa_validacion_pct,
    
    -- Análisis de redirecciones REALES
    COUNT(DISTINCT id_CTransferencia) as destinos_redireccion_diferentes,
    SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as casos_con_redireccion,
    
    -- Análisis de procesamiento interno (SIN asumir transferencia)
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as casos_procesamiento_diferente,
    
    -- Duración promedio
    ROUND(AVG(TIMESTAMPDIFF(SECOND, 
        STR_TO_DATE(CONCAT(fecha, ' ', hora_inicio), '%d/%m/%Y %H:%i:%s'),
        STR_TO_DATE(CONCAT(fecha, ' ', hora_fin), '%d/%m/%Y %H:%i:%s')
    )), 2) as duracion_promedio_seg

FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu, opcion
ORDER BY total_usos DESC;
```

### **5. Análisis de Referencias para Joins Futuros**

```sql
-- CONCEPTO: Preparar análisis para cuando tengas acceso a otras tablas
SELECT 
    'CON_CIDENTIFICA' as tipo_registro,
    COUNT(*) as total_registros,
    COUNT(DISTINCT cIdentifica) as referencias_unicas,
    COUNT(DISTINCT numero_entrada) as usuarios_con_referencias,
    
    -- Contexto de registros con referencias
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_con_referencias,
    SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as tambien_con_redireccion,
    
    -- Patrones de etiquetas en registros con referencias
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as con_validacion_vsi
    
FROM llamadas_Q1
WHERE cIdentifica IS NOT NULL AND cIdentifica != ''

UNION ALL

SELECT 
    'SIN_CIDENTIFICA' as tipo_registro,
    COUNT(*) as total_registros,
    0 as referencias_unicas,
    COUNT(DISTINCT numero_entrada) as usuarios_sin_referencias,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_sin_referencias,
    SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as tambien_con_redireccion,
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as con_validacion_vsi
    
FROM llamadas_Q1
WHERE cIdentifica IS NULL OR cIdentifica = '';
```

### **6. Análisis de Usuarios por Comportamiento de Redirección (Corregido)**

```sql
-- CONCEPTO: Clasificar usuarios según uso REAL del sistema de redirecciones
WITH perfil_usuario AS (
    SELECT 
        numero_entrada,
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT fecha) as dias_activos,
        
        -- Análisis de redirecciones REALES
        COUNT(DISTINCT id_CTransferencia) as destinos_redireccion_diferentes,
        SUM(CASE WHEN id_CTransferencia IS NOT NULL AND id_CTransferencia != '' THEN 1 ELSE 0 END) as interacciones_con_redireccion,
        
        -- Análisis de procesamiento interno (NO transferencias)
        SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as casos_procesamiento_interno,
        
        -- Análisis de validación
        SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as interacciones_validadas,
        
        -- Análisis de referencias futuras
        COUNT(DISTINCT cIdentifica) as referencias_cIdentifica,
        
        -- Análisis de comportamiento
        SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) as interacciones_servicio,
        SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas

    FROM llamadas_Q1
    GROUP BY numero_entrada
)
SELECT 
    CASE 
        WHEN interacciones_con_redireccion > 0 AND destinos_redireccion_diferentes > 2 THEN 'USUARIO_MULTI_REDIRECCION'
        WHEN interacciones_con_redireccion > 0 THEN 'USUARIO_CON_REDIRECCION'
        WHEN casos_procesamiento_interno > total_interacciones * 0.5 THEN 'USUARIO_PROCESAMIENTO_INTERNO'
        WHEN interacciones_validadas > total_interacciones * 0.8 THEN 'USUARIO_VALIDADO_SISTEMA'
        WHEN interacciones_fallidas > total_interacciones * 0.5 THEN 'USUARIO_PROBLEMATICO'
        WHEN referencias_cIdentifica > 0 THEN 'USUARIO_CON_REFERENCIAS_EXTERNAS'
        ELSE 'USUARIO_ESTANDAR'
    END as perfil_usuario,
    
    COUNT(*) as usuarios_en_perfil,
    ROUND(AVG(total_interacciones), 2) as promedio_interacciones,
    ROUND(AVG(interacciones_con_redireccion * 100.0 / total_interacciones), 1) as promedio_pct_con_redireccion,
    ROUND(AVG(casos_procesamiento_interno * 100.0 / total_interacciones), 1) as promedio_pct_procesamiento_interno

FROM perfil_usuario
GROUP BY perfil_usuario
ORDER BY usuarios_en_perfil DESC;
```

---

## Interpretaciones Corregidas

### **Eliminadas las Referencias Incorrectas a:**
- "Transferencias" basadas en `numero_entrada != numero_digitado`
- "Análisis de red de transferencias" usando campos incorrectos
- "Flujos entre números" asumiendo transferencias

### **Nuevos Conceptos Correctos:**
- **Redirecciones**: Solo usando `id_CTransferencia`
- **Procesamiento interno**: Cuando los números difieren por lógica de negocio
- **Referencias futuras**: `cIdentifica` para joins pendientes
- **Validación del sistema**: Usando patrones en etiquetas

### **Para tu Reporte de Promedio de Interacciones:**
Ahora puedes analizar correctamente:
- Comportamiento real de usuarios (sin asumir transferencias falsas)
- Eficiencia del sistema de redirecciones (usando campo correcto)
- Calidad de procesamiento (usando etiquetas como indicador)
- Preparación para análisis futuros (cuando tengas acceso a otras tablas)

Los análisis ahora reflejan la realidad del sistema sin interpretaciones incorrectas de los datos.