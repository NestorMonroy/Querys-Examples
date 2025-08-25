-- ====================================================================
-- INFORMACIÓN DEL ENTORNO
-- ====================================================================

SELECT 'EJECUTADO EN:' as info;

SELECT 
    DATABASE() as 'Base de Datos'
    , USER() as 'Usuario'
    , @@version as 'Versión MySQL/MariaDB'
FROM DUAL;

SELECT NOW() as 'FECHA DE INICIO';

/*********************************************************************************************
     Script          : VALIDACIONES_CONSISTENCIA_CRÍTICA_CROSS_TRIMESTRAL
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Descripción     : Análisis completo de integridad lógica y reglas de negocio
                      across las 3 tablas trimestrales con detección de inconsistencias críticas
     
     Parámetros Variables:
     - @Q1_nombre, @Q2_nombre, @Q3_nombre: Nombres de trimestres
     - @O01, @O02: IDs específicos para análisis
     
     Tablas Target   : productos_t1, productos_t2, productos_t3
     
     Validaciones    : 1. Consistencia temporal (cHInicio < cHFin)
                      2. Lógica de negocio (cSeleccion vs cIOT)
                      3. Duplicados lógicos mismo día
                      4. Rangos válidos de variables
                      5. Integridad referencial
     
     Hipótesis      : H0: Los datos cumplen reglas de consistencia establecidas
                     H1: Existen violaciones sistemáticas a reglas de negocio
                     H2: Inconsistencias varían entre trimestres
     
     Notas          : Identifica errores críticos que pueden invalidar análisis posteriores

*********************************************************************************************/

-- ====================================================================
-- CONFIGURACIÓN DE VARIABLES POR TRIMESTRE
-- ====================================================================

-- ====================================================================
-- MÉTODO 1: FECHAS FIJAS (Configuración manual)
-- ====================================================================

-- Definir variables para rangos de fechas de cada trimestre
SET @Q1_nombre = 'Q01_25';
SET @Q1_inicio = '2025-02-01';
SET @Q1_fin = '2025-03-31';

SET @Q2_nombre = 'Q02_25';
SET @Q2_inicio = '2025-04-01';
SET @Q2_fin = '2025-06-30';

SET @Q3_nombre = 'Q03_25';
SET @Q3_inicio = '2025-07-01';
SET @Q3_fin = '2025-07-31';

-- Variables de IDT específicos para análisis
SET @O01 = 9544745;
SET @O02 = 367620;

-- Mostrar configuración final seleccionada
SELECT 
    'CONFIGURACIÓN DE VARIABLES' as seccion
    , @Q1_nombre as Q1_nombre
    , @Q1_inicio as Q1_inicio
    , @Q1_fin as Q1_fin
    , @Q2_nombre as Q2_nombre
    , @Q2_inicio as Q2_inicio
    , @Q2_fin as Q2_fin
    , @Q3_nombre as Q3_nombre
    , @Q3_inicio as Q3_inicio
    , @Q3_fin as Q3_fin
    , @O01 as IDT_01
    , @O02 as IDT_02;

-- Mostrar estadísticas iniciales para monitoreo
SELECT 
    'INICIO DEL PROCESO' as evento
    , NOW() as timestamp
    , CONNECTION_ID() as connection_id
FROM DUAL;

-- ====================================================================
-- CONTEO DE DATOS EXISTENTES
-- ====================================================================

-- Contar registros por trimestre ANTES del análisis de consistencia
SELECT 'ANTES - REGISTROS POR TRIMESTRE PARA VALIDACIÓN' as reporte;

SELECT 
    @Q1_nombre as trimestre,
    @Q1_inicio as fecha_inicio,
    @Q1_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END) as registros_con_horarios,
    COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END) as registros_con_logica_negocio
FROM productos_t1
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    @Q2_inicio as fecha_inicio,
    @Q2_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END) as registros_con_horarios,
    COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END) as registros_con_logica_negocio
FROM productos_t2
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    @Q3_inicio as fecha_inicio,
    @Q3_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END) as registros_con_horarios,
    COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END) as registros_con_logica_negocio
FROM productos_t3
WHERE cIDT IN (@O01, @O02);

-- ====================================================================
-- ANÁLISIS PRINCIPAL - VALIDACIONES DE CONSISTENCIA CRÍTICA
-- ====================================================================

SELECT 'VALIDACIONES DE CONSISTENCIA - ANÁLISIS INTEGRAL POR TRIMESTRE' as proceso;

-- Análisis completo de violaciones a reglas de consistencia
SELECT 
    @Q1_nombre as trimestre,
    COUNT(*) as total_registros,
    
    -- ===== CONSISTENCIA TEMPORAL =====
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) as violaciones_orden_temporal,
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) > 28800 THEN 1 END) as sesiones_excesivas_8h,
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) < 60 THEN 1 END) as sesiones_muy_cortas_1min,
    COUNT(CASE WHEN TIME_TO_SEC(cHInicio) < TIME_TO_SEC('06:00:00') THEN 1 END) as inicio_muy_temprano,
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) > TIME_TO_SEC('23:00:00') THEN 1 END) as fin_muy_tarde,
    
    -- ===== CONSISTENCIA LÓGICA DE NEGOCIO =====
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) as seleccionado_sin_iot,
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END) as no_seleccionado_con_iot,
    COUNT(CASE WHEN cSeleccion IS NULL OR cIOT IS NULL THEN 1 END) as logica_negocio_nula,
    COUNT(CASE WHEN cSeleccion NOT IN (0, 1) THEN 1 END) as seleccion_fuera_rango,
    COUNT(CASE WHEN cIOT NOT IN (0, 1) THEN 1 END) as iot_fuera_rango,
    
    -- ===== DUPLICADOS Y INTEGRIDAD =====
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, DATE(cFecha), cIDT)) as duplicados_logicos_mismo_dia,
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, cIDT, cHInicio, cHFin)) as duplicados_exactos_horario,
    COUNT(CASE WHEN cProducto <= 0 THEN 1 END) as productos_invalidos_cero_negativo,
    
    -- ===== CONSISTENCIA DE FECHAS =====
    COUNT(CASE WHEN cFecha < @Q1_inicio OR cFecha > @Q1_fin THEN 1 END) as fechas_fuera_rango_trimestre,
    COUNT(CASE WHEN DAYOFWEEK(cFecha) IN (1,7) THEN 1 END) as registros_fines_semana,
    COUNT(CASE WHEN HOUR(cFecha) BETWEEN 0 AND 5 THEN 1 END) as registros_madrugada,
    
    -- ===== MÉTRICAS DE CONSISTENCIA GLOBAL =====
    ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2) as consistencia_temporal_pct,
    ROUND((COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)), 2) as consistencia_logica_negocio_pct,
    ROUND((COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)), 2) as consistencia_productos_validos_pct,
    
    -- ===== SCORE DE INTEGRIDAD GLOBAL =====
    ROUND(((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
           (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
           (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3), 2),
    CASE 
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 98 THEN 'CONSISTENCIA_EXCELENTE'
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 95 THEN 'CONSISTENCIA_BUENA'
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 90 THEN 'CONSISTENCIA_ACEPTABLE'
        ELSE 'CONSISTENCIA_CRÍTICA'
    END
    
FROM productos_t3 
WHERE cIDT IN (@O01, @O02)

ORDER BY trimestre;

-- ====================================================================
-- ANÁLISIS DETALLADO POR cIDT Y cCATEGORIA
-- ====================================================================

SELECT 'ANÁLISIS DETALLADO - CONSISTENCIA POR cIDT Y cCATEGORIA' as proceso_detallado;

-- Análisis granular de consistencia agrupado
SELECT 
    @Q1_nombre as trimestre,
    cIDT,
    COALESCE(cCategoria, '[NULL_CATEGORIA]') as categoria_analizada,
    COUNT(*) as total_registros,
    
    -- Violaciones específicas por grupo
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) as horarios_inconsistentes,
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) as sel_sin_iot,
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END) as no_sel_con_iot,
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, DATE(cFecha))) as dup_producto_fecha,
    
    -- Porcentajes de consistencia por grupo
    ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2) as consistencia_temporal_pct,
    ROUND((COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)), 2) as consistencia_logica_pct,
    
    -- Indicador de salud del grupo
    CASE 
        WHEN COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) = 0 
         AND COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) = 0
         AND COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END) = 0 THEN 'GRUPO_SALUDABLE'
        WHEN COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) <= 2 
         AND COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) <= 2 THEN 'GRUPO_ACEPTABLE'
        ELSE 'GRUPO_PROBLEMÁTICO'
    END as estado_grupo
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
GROUP BY cIDT, cCategoria

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    cIDT,
    COALESCE(cCategoria, '[NULL_CATEGORIA]'),
    COUNT(*),
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END),
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, DATE(cFecha))),
    ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2),
    ROUND((COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)), 2),
    CASE 
        WHEN COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) = 0 
         AND COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) = 0
         AND COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END) = 0 THEN 'GRUPO_SALUDABLE'
        WHEN COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) <= 2 
         AND COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) <= 2 THEN 'GRUPO_ACEPTABLE'
        ELSE 'GRUPO_PROBLEMÁTICO'
    END
FROM productos_t2 WHERE cIDT IN (@O01, @O02) GROUP BY cIDT, cCategoria

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    cIDT,
    COALESCE(cCategoria, '[NULL_CATEGORIA]'),
    COUNT(*),
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END),
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, DATE(cFecha))),
    ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2),
    ROUND((COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)), 2),
    CASE 
        WHEN COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) = 0 
         AND COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) = 0
         AND COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END) = 0 THEN 'GRUPO_SALUDABLE'
        WHEN COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END) <= 2 
         AND COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END) <= 2 THEN 'GRUPO_ACEPTABLE'
        ELSE 'GRUPO_PROBLEMÁTICO'
    END
FROM productos_t3 WHERE cIDT IN (@O01, @O02) GROUP BY cIDT, cCategoria

ORDER BY cIDT, categoria_analizada, trimestre;

-- ====================================================================
-- ANÁLISIS DE REGISTROS CRÍTICOS - MÚLTIPLES VIOLACIONES
-- ====================================================================

SELECT 'IDENTIFICACIÓN DE REGISTROS CON MÚLTIPLES VIOLACIONES DE CONSISTENCIA' as proceso_critico;

-- Registros con múltiples problemas de consistencia (solo muestra para T1, replicar para T2 y T3)
SELECT 
    @Q1_nombre as trimestre,
    cProducto,
    cIDT,
    cCategoria,
    cFecha,
    cHInicio,
    cHFin,
    cSeleccion,
    cIOT,
    
    -- Contador de violaciones
    (CASE WHEN cHInicio >= cHFin THEN 1 ELSE 0 END +
     CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 ELSE 0 END +
     CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 ELSE 0 END +
     CASE WHEN cProducto <= 0 THEN 1 ELSE 0 END +
     CASE WHEN cFecha < @Q1_inicio OR cFecha > @Q1_fin THEN 1 ELSE 0 END) as total_violaciones,
    
    -- Descripción de violaciones
    CONCAT_WS(', ',
        CASE WHEN cHInicio >= cHFin THEN 'Horario_Inconsistente' END,
        CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 'Seleccionado_Sin_IOT' END,
        CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 'No_Seleccionado_Con_IOT' END,
        CASE WHEN cProducto <= 0 THEN 'Producto_Inválido' END,
        CASE WHEN cFecha < @Q1_inicio OR cFecha > @Q1_fin THEN 'Fecha_Fuera_Rango' END
    ) as descripcion_violaciones
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)
  AND ((cHInicio >= cHFin) OR 
       (cSeleccion = 1 AND cIOT = 0) OR 
       (cSeleccion = 0 AND cIOT = 1) OR 
       (cProducto <= 0) OR 
       (cFecha < @Q1_inicio OR cFecha > @Q1_fin))
ORDER BY total_violaciones DESC, cFecha DESC
LIMIT 100;  -- Mostrar solo los 100 casos más críticos

-- ====================================================================
-- FINALIZACIÓN Y ESTADÍSTICAS
-- ====================================================================

SELECT 
    'FIN DEL ANÁLISIS DE CONSISTENCIA' as evento
    , NOW() as timestamp_fin
    , 'Validaciones completadas exitosamente' as status
    , 'Revisar registros con clasificacion CONSISTENCIA_CRÍTICA' as recomendacion
FROM DUAL; / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
           (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3), 2) as score_integridad_global,
    
    -- ===== CLASIFICACIÓN DE CONSISTENCIA =====
    CASE 
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 98 THEN 'CONSISTENCIA_EXCELENTE'
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 95 THEN 'CONSISTENCIA_BUENA'
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 90 THEN 'CONSISTENCIA_ACEPTABLE'
        ELSE 'CONSISTENCIA_CRÍTICA'
    END as clasificacion_consistencia
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    COUNT(*) as total_registros,
    
    -- Consistencia temporal
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) > 28800 THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) < 60 THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHInicio) < TIME_TO_SEC('06:00:00') THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) > TIME_TO_SEC('23:00:00') THEN 1 END),
    
    -- Consistencia lógica
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END),
    COUNT(CASE WHEN cSeleccion IS NULL OR cIOT IS NULL THEN 1 END),
    COUNT(CASE WHEN cSeleccion NOT IN (0, 1) THEN 1 END),
    COUNT(CASE WHEN cIOT NOT IN (0, 1) THEN 1 END),
    
    -- Duplicados e integridad
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, DATE(cFecha), cIDT)),
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, cIDT, cHInicio, cHFin)),
    COUNT(CASE WHEN cProducto <= 0 THEN 1 END),
    
    -- Consistencia de fechas
    COUNT(CASE WHEN cFecha < @Q2_inicio OR cFecha > @Q2_fin THEN 1 END),
    COUNT(CASE WHEN DAYOFWEEK(cFecha) IN (1,7) THEN 1 END),
    COUNT(CASE WHEN HOUR(cFecha) BETWEEN 0 AND 5 THEN 1 END),
    
    -- Métricas de consistencia
    ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2),
    ROUND((COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)), 2),
    ROUND((COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)), 2),
    
    -- Score global
    ROUND(((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
           (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
           (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3), 2),
    
    -- Clasificación
    CASE 
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 98 THEN 'CONSISTENCIA_EXCELENTE'
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 95 THEN 'CONSISTENCIA_BUENA'
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 90 THEN 'CONSISTENCIA_ACEPTABLE'
        ELSE 'CONSISTENCIA_CRÍTICA'
    END as clasificacion_consistencia
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    COUNT(*),
    
    -- Consistencia temporal
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) > 28800 THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) < 60 THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHInicio) < TIME_TO_SEC('06:00:00') THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) > TIME_TO_SEC('23:00:00') THEN 1 END),
    
    -- Consistencia lógica
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END),
    COUNT(CASE WHEN cSeleccion IS NULL OR cIOT IS NULL THEN 1 END),
    COUNT(CASE WHEN cSeleccion NOT IN (0, 1) THEN 1 END),
    COUNT(CASE WHEN cIOT NOT IN (0, 1) THEN 1 END),
    
    -- Duplicados e integridad
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, DATE(cFecha), cIDT)),
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, cIDT, cHInicio, cHFin)),
    COUNT(CASE WHEN cProducto <= 0 THEN 1 END),
    
    -- Consistencia de fechas
    COUNT(CASE WHEN cFecha < @Q3_inicio OR cFecha > @Q3_fin THEN 1 END),
    COUNT(CASE WHEN DAYOFWEEK(cFecha) IN (1,7) THEN 1 END),
    COUNT(CASE WHEN HOUR(cFecha) BETWEEN 0 AND 5 THEN 1 END),
    
    -- Métricas globales
    ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2),
    ROUND((COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)), 2),
    ROUND((COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)), 2),
    
    -- Score y clasificación
    ROUND(((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
           (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
           (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3), 2),
    CASE 
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 98 THEN 'CONSISTENCIA_EXCELENTE'
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 95 THEN 'CONSISTENCIA_BUENA'
        WHEN ((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
              (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)) * 0.3 +
              (COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)) * 0.3) >= 90 THEN 'CONSISTENCIA_ACEPTABLE'
        ELSE 'CONSISTENCIA_CRÍTICA'
    END
    
FROM productos_t2 
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    COUNT(*),
    
    -- Consistencia temporal
    COUNT(CASE WHEN cHInicio >= cHFin THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) > 28800 THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) - TIME_TO_SEC(cHInicio) < 60 THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHInicio) < TIME_TO_SEC('06:00:00') THEN 1 END),
    COUNT(CASE WHEN TIME_TO_SEC(cHFin) > TIME_TO_SEC('23:00:00') THEN 1 END),
    
    -- Consistencia lógica
    COUNT(CASE WHEN cSeleccion = 1 AND cIOT = 0 THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 0 AND cIOT = 1 THEN 1 END),
    COUNT(CASE WHEN cSeleccion IS NULL OR cIOT IS NULL THEN 1 END),
    COUNT(CASE WHEN cSeleccion NOT IN (0, 1) THEN 1 END),
    COUNT(CASE WHEN cIOT NOT IN (0, 1) THEN 1 END),
    
    -- Duplicados e integridad
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, DATE(cFecha), cIDT)),
    COUNT(*) - COUNT(DISTINCT CONCAT(cProducto, cIDT, cHInicio, cHFin)),
    COUNT(CASE WHEN cProducto <= 0 THEN 1 END),
    
    -- Consistencia de fechas
    COUNT(CASE WHEN cFecha < @Q3_inicio OR cFecha > @Q3_fin THEN 1 END),
    COUNT(CASE WHEN DAYOFWEEK(cFecha) IN (1,7) THEN 1 END),
    COUNT(CASE WHEN HOUR(cFecha) BETWEEN 0 AND 5 THEN 1 END),
    
    -- Métricas globales
    ROUND((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)), 2),
    ROUND((COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0 / 
           COUNT(CASE WHEN cSeleccion IS NOT NULL AND cIOT IS NOT NULL THEN 1 END)), 2),
    ROUND((COUNT(CASE WHEN cProducto > 0 THEN 1 END) * 100.0 / COUNT(CASE WHEN cProducto IS NOT NULL THEN 1 END)), 2),
    
    -- Score y clasificación
    ROUND(((COUNT(CASE WHEN cHInicio < cHFin THEN 1 END) * 100.0 / COUNT(CASE WHEN cHInicio IS NOT NULL AND cHFin IS NOT NULL THEN 1 END)) * 0.4 +
           (COUNT(CASE WHEN (cSeleccion = 1 AND cIOT = 1) OR (cSeleccion = 0 AND cIOT = 0) THEN 1 END) * 100.0