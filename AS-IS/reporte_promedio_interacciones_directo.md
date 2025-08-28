# Reporte Directo: Promedio Interacciones y Patrones de Usuario

## Requerimiento Específico
- Promedio de interacciones por numero_entrada por día
- Escalabilidad temporal: semana, mes, año  
- Identificación de patrones de navegación por usuario

---

## 1. Reporte Base: Promedio Diario

### **Query Principal - Promedio por Día:**
```sql
-- REPORTE SOLICITADO: Promedio de interacciones por numero_entrada por día
SELECT 
    fecha,
    COUNT(DISTINCT numero_entrada) as usuarios_activos,
    COUNT(*) as total_interacciones,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_interacciones_por_usuario,
    
    -- Métricas adicionales de contexto
    MIN(hora_inicio) as primera_interaccion_dia,
    MAX(hora_fin) as ultima_interaccion_dia,
    COUNT(DISTINCT menu) as menus_utilizados,
    COUNT(DISTINCT id_8T) as zonas_activas

FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL
    SELECT * FROM llamadas_Q2  
    UNION ALL
    SELECT * FROM llamadas_Q3
) todas_llamadas

WHERE numero_entrada IS NOT NULL
GROUP BY fecha
ORDER BY fecha;
```

### **Query con Filtro de Calidad (Recomendado):**
```sql
-- VERSIÓN CON FILTROS DE CALIDAD
SELECT 
    fecha,
    COUNT(DISTINCT numero_entrada) as usuarios_activos,
    COUNT(*) as interacciones_validas,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_interacciones_por_usuario,
    
    -- Distribución por tipo de interacción
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as interacciones_validadas,
    SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas,
    
    -- Porcentajes
    ROUND(SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_validadas,
    ROUND(SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_fallidas

FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL
    SELECT * FROM llamadas_Q2  
    UNION ALL
    SELECT * FROM llamadas_Q3
) todas_llamadas

WHERE numero_entrada IS NOT NULL
  AND menu IS NOT NULL  -- Filtrar registros sin menú
GROUP BY fecha
ORDER BY fecha;
```

---

## 2. Escalabilidad Temporal

### **Reporte Semanal:**
```sql
-- PROMEDIO SEMANAL
SELECT 
    YEAR(STR_TO_DATE(fecha, '%d/%m/%Y')) as año,
    WEEK(STR_TO_DATE(fecha, '%d/%m/%Y'), 1) as semana,
    
    -- Métricas semanales
    COUNT(DISTINCT fecha) as dias_con_datos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos_semana,
    COUNT(*) as total_interacciones_semana,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_interacciones_usuario_semana,
    
    -- Promedio diario dentro de la semana
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada) / COUNT(DISTINCT fecha), 2) as promedio_diario_en_semana,
    
    -- Fechas de la semana
    MIN(fecha) as primer_dia_semana,
    MAX(fecha) as ultimo_dia_semana

FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL
    SELECT * FROM llamadas_Q2  
    UNION ALL
    SELECT * FROM llamadas_Q3
) todas_llamadas

WHERE numero_entrada IS NOT NULL
GROUP BY YEAR(STR_TO_DATE(fecha, '%d/%m/%Y')), WEEK(STR_TO_DATE(fecha, '%d/%m/%Y'), 1)
ORDER BY año, semana;
```

### **Reporte Mensual:**
```sql
-- PROMEDIO MENSUAL
SELECT 
    YEAR(STR_TO_DATE(fecha, '%d/%m/%Y')) as año,
    MONTH(STR_TO_DATE(fecha, '%d/%m/%Y')) as mes,
    MONTHNAME(STR_TO_DATE(fecha, '%d/%m/%Y')) as nombre_mes,
    
    -- Métricas mensuales
    COUNT(DISTINCT fecha) as dias_con_datos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos_mes,
    COUNT(*) as total_interacciones_mes,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_interacciones_usuario_mes,
    
    -- Promedio diario dentro del mes
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada) / COUNT(DISTINCT fecha), 2) as promedio_diario_en_mes

FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL
    SELECT * FROM llamadas_Q2  
    UNION ALL
    SELECT * FROM llamadas_Q3
) todas_llamadas

WHERE numero_entrada IS NOT NULL
GROUP BY YEAR(STR_TO_DATE(fecha, '%d/%m/%Y')), MONTH(STR_TO_DATE(fecha, '%d/%m/%Y'))
ORDER BY año, mes;
```

### **Reporte Anual:**
```sql
-- PROMEDIO ANUAL
SELECT 
    YEAR(STR_TO_DATE(fecha, '%d/%m/%Y')) as año,
    
    -- Métricas anuales
    COUNT(DISTINCT fecha) as dias_con_datos,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos_año,
    COUNT(*) as total_interacciones_año,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_interacciones_usuario_año,
    
    -- Desglose por trimestre
    SUM(CASE WHEN MONTH(STR_TO_DATE(fecha, '%d/%m/%Y')) BETWEEN 1 AND 3 THEN 1 ELSE 0 END) as interacciones_Q1,
    SUM(CASE WHEN MONTH(STR_TO_DATE(fecha, '%d/%m/%Y')) BETWEEN 4 AND 6 THEN 1 ELSE 0 END) as interacciones_Q2,
    SUM(CASE WHEN MONTH(STR_TO_DATE(fecha, '%d/%m/%Y')) BETWEEN 7 AND 9 THEN 1 ELSE 0 END) as interacciones_Q3,
    SUM(CASE WHEN MONTH(STR_TO_DATE(fecha, '%d/%m/%Y')) BETWEEN 10 AND 12 THEN 1 ELSE 0 END) as interacciones_Q4

FROM (
    SELECT * FROM llamadas_Q1
    UNION ALL
    SELECT * FROM llamadas_Q2  
    UNION ALL
    SELECT * FROM llamadas_Q3
) todas_llamadas

WHERE numero_entrada IS NOT NULL
GROUP BY YEAR(STR_TO_DATE(fecha, '%d/%m/%Y'))
ORDER BY año;
```

---

## 3. Identificación de Patrones por Usuario

### **Patrones de Navegación por numero_entrada:**
```sql
-- PATRONES DE MENÚ/OPCIÓN POR USUARIO
SELECT 
    numero_entrada,
    fecha,
    COUNT(*) as total_interacciones_dia,
    
    -- Secuencia de navegación completa
    GROUP_CONCAT(
        CONCAT(
            TIME_FORMAT(
                CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END, 
                '%H:%i'
            ),
            ':[', COALESCE(menu, 'SIN_MENU'), 
            CASE WHEN opcion IS NOT NULL AND opcion != '' 
                 THEN CONCAT('-', opcion) ELSE '' END, ']'
        )
        ORDER BY CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END
        SEPARATOR ' → '
    ) as patron_navegacion,
    
    -- Análisis de menús utilizados
    COUNT(DISTINCT menu) as menus_diferentes,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu) as menus_utilizados,
    
    -- Análisis de redirecciones
    COUNT(DISTINCT id_CTransferencia) as redirecciones_diferentes,
    
    -- Análisis de validación
    SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as interacciones_validadas,
    SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas,
    
    -- Duración total de la sesión
    TIMESTAMPDIFF(SECOND, 
        MIN(STR_TO_DATE(CONCAT(fecha, ' ', CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END), '%d/%m/%Y %H:%i:%s')),
        MAX(STR_TO_DATE(CONCAT(fecha, ' ', CASE WHEN hora_fin < hora_inicio THEN hora_inicio ELSE hora_fin END), '%d/%m/%Y %H:%i:%s'))
    ) as duracion_sesion_segundos

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

### **Clasificación de Usuarios por Patrón:**
```sql
-- CLASIFICACIÓN DE USUARIOS POR TIPO DE COMPORTAMIENTO
WITH perfil_usuario AS (
    SELECT 
        numero_entrada,
        COUNT(*) as total_interacciones,
        COUNT(DISTINCT fecha) as dias_activos,
        ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT fecha), 2) as promedio_interacciones_por_dia,
        
        -- Análisis de menús
        COUNT(DISTINCT menu) as diversidad_menus,
        GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as top_menus,
        
        -- Análisis de comportamiento
        SUM(CASE WHEN menu LIKE 'RES-%' THEN 1 ELSE 0 END) as interacciones_servicios,
        SUM(CASE WHEN menu LIKE 'comercial_%' THEN 1 ELSE 0 END) as interacciones_comerciales,
        SUM(CASE WHEN menu IN ('cte_colgo', 'SinOpcion_Cbc') THEN 1 ELSE 0 END) as interacciones_fallidas,
        SUM(CASE WHEN menu = 'SDO' THEN 1 ELSE 0 END) as consultas_saldo,
        
        -- Análisis de validación
        SUM(CASE WHEN etiquetas LIKE '%VSI%' THEN 1 ELSE 0 END) as interacciones_validadas,
        
        -- Análisis organizacional
        COUNT(DISTINCT id_8T) as zonas_utilizadas,
        COUNT(DISTINCT division) as divisiones_diferentes

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
    CASE 
        WHEN promedio_interacciones_por_dia >= 10 THEN 'USUARIO_INTENSIVO'
        WHEN interacciones_comerciales > 0 THEN 'USUARIO_COMERCIAL'
        WHEN interacciones_servicios > interacciones_fallidas THEN 'USUARIO_SERVICIOS'
        WHEN consultas_saldo = total_interacciones THEN 'USUARIO_CONSULTA_SIMPLE'
        WHEN interacciones_fallidas > total_interacciones * 0.6 THEN 'USUARIO_PROBLEMATICO'
        WHEN diversidad_menus >= 5 THEN 'USUARIO_EXPLORADOR'
        WHEN dias_activos >= 10 THEN 'USUARIO_RECURRENTE'
        ELSE 'USUARIO_ESTANDAR'
    END as tipo_usuario,
    
    COUNT(*) as cantidad_usuarios,
    ROUND(AVG(total_interacciones), 2) as promedio_interacciones_tipo,
    ROUND(AVG(promedio_interacciones_por_dia), 2) as promedio_diario_tipo,
    ROUND(AVG(diversidad_menus), 1) as promedio_diversidad_menus

FROM perfil_usuario
GROUP BY tipo_usuario
ORDER BY cantidad_usuarios DESC;
```

---

## 4. Resumen Ejecutivo del Reporte

### **Entregables Directos:**
1. **Tabla de promedio diario** por fecha
2. **Escalabilidad temporal** (semanal, mensual, anual)  
3. **Patrones individuales** por numero_entrada
4. **Clasificación de tipos de usuario** según comportamiento

### **Métricas Clave:**
- Promedio de interacciones por usuario por día
- Distribución de tipos de usuario
- Evolución temporal de promedios
- Patrones de navegación más frecuentes

### **Decisiones de Filtrado Recomendadas:**
- Incluir solo registros con `numero_entrada` válido
- Filtrar registros sin menú (datos incompletos)
- Considerar usar etiquetas VSI como indicador de calidad
- Manejar timestamps invertidos en cálculos de duración

**Este es el reporte directo que necesitas. ¿Quieres que ajuste alguno de estos queries específicos para tu caso?**