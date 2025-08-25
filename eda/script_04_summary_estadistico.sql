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
     Script          : SUMMARY_ESTADÍSTICO_COMPLETO_CROSS_TRIMESTRAL
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Descripción     : Análisis estadístico descriptivo completo equivalente a summary() de R
                      para todas las variables numéricas across los 3 trimestres
     
     Parámetros Variables:
     - @Q1_nombre, @Q2_nombre, @Q3_nombre: Nombres de trimestres
     - @O01, @O02: IDs específicos para análisis
     
     Tablas Target   : productos_t1, productos_t2, productos_t3
     
     Variables Analizadas:
     - cProducto: Variable numérica principal (BIGINT)
     - cSeleccion: Variable binaria (0/1)
     - cIOT: Variable binaria (0/1)
     
     Estadísticos    : MIN, MAX, MEAN, MEDIAN (aprox), STDDEV, VARIANCE, 
                      Coef. Variación, Cuartiles (aprox), Rango, Moda
     
     Hipótesis      : H0: Las distribuciones son estables entre trimestres
                     H1: Existen cambios significativos en parámetros estadísticos
                     H2: Variables siguen distribuciones normales
     
     Notas          : Proporciona caracterización completa de la forma y centralidad

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

-- Contar registros por trimestre ANTES del análisis estadístico
SELECT 'ANTES - REGISTROS POR TRIMESTRE PARA ANÁLISIS ESTADÍSTICO' as reporte;

SELECT 
    @Q1_nombre as trimestre,
    @Q1_inicio as fecha_inicio,
    @Q1_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(cProducto) as registros_producto_validos,
    COUNT(cSeleccion) as registros_seleccion_validos,
    COUNT(cIOT) as registros_iot_validos
FROM productos_t1
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    @Q2_inicio as fecha_inicio,
    @Q2_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(cProducto) as registros_producto_validos,
    COUNT(cSeleccion) as registros_seleccion_validos,
    COUNT(cIOT) as registros_iot_validos
FROM productos_t2
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    @Q3_inicio as fecha_inicio,
    @Q3_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(cProducto) as registros_producto_validos,
    COUNT(cSeleccion) as registros_seleccion_validos,
    COUNT(cIOT) as registros_iot_validos
FROM productos_t3
WHERE cIDT IN (@O01, @O02);

-- ====================================================================
-- ANÁLISIS PRINCIPAL - SUMMARY ESTADÍSTICO PARA cPRODUCTO
-- ====================================================================

SELECT 'SUMMARY ESTADÍSTICO COMPLETO - VARIABLE cPRODUCTO' as proceso;

-- Análisis estadístico descriptivo completo para cProducto
SELECT 
    @Q1_nombre as trimestre,
    'cProducto' as variable,
    COUNT(*) as n_total,
    COUNT(cProducto) as n_validos,
    COUNT(*) - COUNT(cProducto) as n_nulos,
    ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2) as completitud_pct,
    
    -- ===== ESTADÍSTICAS DE TENDENCIA CENTRAL =====
    MIN(cProducto) as minimo,
    MAX(cProducto) as maximo,
    ROUND(AVG(cProducto), 0) as media_aritmetica,
    
    -- ===== ESTADÍSTICAS DE DISPERSIÓN =====
    ROUND(STDDEV(cProducto), 0) as desviacion_estandar,
    ROUND(VARIANCE(cProducto), 0) as varianza,
    MAX(cProducto) - MIN(cProducto) as rango_total,
    ROUND((STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) * 100, 2) as coeficiente_variacion_pct,
    
    -- ===== APROXIMACIÓN DE CUARTILES =====
    -- Q1 (Percentil 25)
    (SELECT cProducto FROM productos_t1 
     WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL 
     ORDER BY cProducto 
     LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.25) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as Q1_percentil_25,
    
    -- Mediana (Percentil 50)
    (SELECT cProducto FROM productos_t1 
     WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL 
     ORDER BY cProducto 
     LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.50) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as mediana_percentil_50,
    
    -- Q3 (Percentil 75)
    (SELECT cProducto FROM productos_t1 
     WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL 
     ORDER BY cProducto 
     LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.75) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as Q3_percentil_75,
    
    -- ===== RANGO INTERCUARTÍLICO (IQR) =====
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.75) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) - 
    (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.25) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) as IQR_rango_intercuartilico,
    
    -- ===== ESTADÍSTICAS DE FORMA (APROXIMADAS) =====
    -- Relación Media vs Mediana (indicador de asimetría)
    ROUND((AVG(cProducto) - (SELECT cProducto FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.50) FROM productos_t1 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL))) / STDDEV(cProducto), 3) as indice_asimetria_aprox,
    
    -- ===== CLASIFICACIÓN DE VARIABILIDAD =====
    CASE 
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.1 THEN 'VARIABILIDAD_MUY_BAJA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.2 THEN 'VARIABILIDAD_BAJA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.5 THEN 'VARIABILIDAD_MODERADA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 1.0 THEN 'VARIABILIDAD_ALTA'
        ELSE 'VARIABILIDAD_MUY_ALTA'
    END as clasificacion_variabilidad
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    'cProducto' as variable,
    COUNT(*), COUNT(cProducto), COUNT(*) - COUNT(cProducto),
    ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
    
    -- Estadísticas centrales
    MIN(cProducto), MAX(cProducto), ROUND(AVG(cProducto), 0),
    
    -- Estadísticas de dispersión
    ROUND(STDDEV(cProducto), 0), ROUND(VARIANCE(cProducto), 0),
    MAX(cProducto) - MIN(cProducto), ROUND((STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) * 100, 2),
    
    -- Cuartiles aproximados
    (SELECT cProducto FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.25) FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)),
    (SELECT cProducto FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.50) FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)),
    (SELECT cProducto FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.75) FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)),
    
    -- IQR
    (SELECT cProducto FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.75) FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) - 
    (SELECT cProducto FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.25) FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)),
    
    -- Asimetría aproximada
    ROUND((AVG(cProducto) - (SELECT cProducto FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.50) FROM productos_t2 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL))) / STDDEV(cProducto), 3),
    
    -- Clasificación variabilidad
    CASE 
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.1 THEN 'VARIABILIDAD_MUY_BAJA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.2 THEN 'VARIABILIDAD_BAJA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.5 THEN 'VARIABILIDAD_MODERADA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 1.0 THEN 'VARIABILIDAD_ALTA'
        ELSE 'VARIABILIDAD_MUY_ALTA'
    END
FROM productos_t2 WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    'cProducto' as variable,
    COUNT(*), COUNT(cProducto), COUNT(*) - COUNT(cProducto),
    ROUND((COUNT(cProducto) * 100.0 / COUNT(*)), 2),
    
    -- Estadísticas centrales
    MIN(cProducto), MAX(cProducto), ROUND(AVG(cProducto), 0),
    
    -- Estadísticas de dispersión
    ROUND(STDDEV(cProducto), 0), ROUND(VARIANCE(cProducto), 0),
    MAX(cProducto) - MIN(cProducto), ROUND((STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) * 100, 2),
    
    -- Cuartiles aproximados
    (SELECT cProducto FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.25) FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)),
    (SELECT cProducto FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.50) FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)),
    (SELECT cProducto FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.75) FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)),
    
    -- IQR
    (SELECT cProducto FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.75) FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)) - 
    (SELECT cProducto FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.25) FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL)),
    
    -- Asimetría aproximada
    ROUND((AVG(cProducto) - (SELECT cProducto FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL ORDER BY cProducto LIMIT 1 OFFSET (SELECT FLOOR(COUNT(cProducto) * 0.50) FROM productos_t3 WHERE cIDT IN (@O01, @O02) AND cProducto IS NOT NULL))) / STDDEV(cProducto), 3),
    
    -- Clasificación variabilidad
    CASE 
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.1 THEN 'VARIABILIDAD_MUY_BAJA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.2 THEN 'VARIABILIDAD_BAJA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 0.5 THEN 'VARIABILIDAD_MODERADA'
        WHEN (STDDEV(cProducto) / NULLIF(AVG(cProducto), 0)) < 1.0 THEN 'VARIABILIDAD_ALTA'
        ELSE 'VARIABILIDAD_MUY_ALTA'
    END
FROM productos_t3 WHERE cIDT IN (@O01, @O02)

ORDER BY trimestre;

-- ====================================================================
-- ANÁLISIS ESTADÍSTICO PARA VARIABLES BINARIAS - cSELECCION
-- ====================================================================

SELECT 'SUMMARY ESTADÍSTICO - VARIABLE BINARIA cSELECCION' as proceso_binario;

-- Análisis específico para variable binaria cSeleccion
SELECT 
    @Q1_nombre as trimestre,
    'cSeleccion' as variable,
    COUNT(*) as n_total,
    COUNT(cSeleccion) as n_validos,
    COUNT(*) - COUNT(cSeleccion) as n_nulos,
    ROUND((COUNT(cSeleccion) * 100.0 / COUNT(*)), 2) as completitud_pct,
    
    -- ===== ESTADÍSTICAS ESPECÍFICAS PARA BINARIAS =====
    MIN(cSeleccion) as valor_minimo,
    MAX(cSeleccion) as valor_maximo,
    COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) as frecuencia_0,
    COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) as frecuencia_1,
    
    -- ===== PROPORCIONES =====
    ROUND((COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) * 100.0 / COUNT(cSeleccion)), 2) as porcentaje_0,
    ROUND((COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) * 100.0 / COUNT(cSeleccion)), 2) as porcentaje_1,
    ROUND(AVG(cSeleccion), 4) as proporcion_media_1,
    
    -- ===== ESTADÍSTICAS DE DISPERSIÓN PARA BINARIAS =====
    ROUND(STDDEV(cSeleccion), 4) as desviacion_estandar,
    ROUND(VARIANCE(cSeleccion), 4) as varianza,
    
    -- ===== MODA =====
    CASE 
        WHEN COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) > COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) THEN 1
        WHEN COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) > COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) THEN 0
        ELSE 'BIMODAL'
    END as moda,
    
    -- ===== CLASIFICACIÓN DE DISTRIBUCIÓN =====
    CASE 
        WHEN AVG(cSeleccion) < 0.1 THEN 'PREDOMINIO_0_FUERTE'
        WHEN AVG(cSeleccion) < 0.3 THEN 'PREDOMINIO_0_MODERADO'
        WHEN AVG(cSeleccion) BETWEEN 0.4 AND 0.6 THEN 'DISTRIBUCIÓN_BALANCEADA'
        WHEN AVG(cSeleccion) < 0.8 THEN 'PREDOMINIO_1_MODERADO'
        ELSE 'PREDOMINIO_1_FUERTE'
    END as clasificacion_distribucion
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    'cSeleccion' as variable,
    COUNT(*), COUNT(cSeleccion), COUNT(*) - COUNT(cSeleccion),
    ROUND((COUNT(cSeleccion) * 100.0 / COUNT(*)), 2),
    
    MIN(cSeleccion), MAX(cSeleccion),
    COUNT(CASE WHEN cSeleccion = 0 THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 1 THEN 1 END),
    ROUND((COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) * 100.0 / COUNT(cSeleccion)), 2),
    ROUND((COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) * 100.0 / COUNT(cSeleccion)), 2),
    ROUND(AVG(cSeleccion), 4),
    ROUND(STDDEV(cSeleccion), 4), ROUND(VARIANCE(cSeleccion), 4),
    
    CASE 
        WHEN COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) > COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) THEN 1
        WHEN COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) > COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) THEN 0
        ELSE 'BIMODAL'
    END,
    
    CASE 
        WHEN AVG(cSeleccion) < 0.1 THEN 'PREDOMINIO_0_FUERTE'
        WHEN AVG(cSeleccion) < 0.3 THEN 'PREDOMINIO_0_MODERADO'
        WHEN AVG(cSeleccion) BETWEEN 0.4 AND 0.6 THEN 'DISTRIBUCIÓN_BALANCEADA'
        WHEN AVG(cSeleccion) < 0.8 THEN 'PREDOMINIO_1_MODERADO'
        ELSE 'PREDOMINIO_1_FUERTE'
    END
FROM productos_t2 WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    'cSeleccion' as variable,
    COUNT(*), COUNT(cSeleccion), COUNT(*) - COUNT(cSeleccion),
    ROUND((COUNT(cSeleccion) * 100.0 / COUNT(*)), 2),
    
    MIN(cSeleccion), MAX(cSeleccion),
    COUNT(CASE WHEN cSeleccion = 0 THEN 1 END),
    COUNT(CASE WHEN cSeleccion = 1 THEN 1 END),
    ROUND((COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) * 100.0 / COUNT(cSeleccion)), 2),
    ROUND((COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) * 100.0 / COUNT(cSeleccion)), 2),
    ROUND(AVG(cSeleccion), 4),
    ROUND(STDDEV(cSeleccion), 4), ROUND(VARIANCE(cSeleccion), 4),
    
    CASE 
        WHEN COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) > COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) THEN 1
        WHEN COUNT(CASE WHEN cSeleccion = 0 THEN 1 END) > COUNT(CASE WHEN cSeleccion = 1 THEN 1 END) THEN 0
        ELSE 'BIMODAL'
    END,
    
    CASE 
        WHEN AVG(cSeleccion) < 0.1 THEN 'PREDOMINIO_0_FUERTE'
        WHEN AVG(cSeleccion) < 0.3 THEN 'PREDOMINIO_0_MODERADO'
        WHEN AVG(cSeleccion) BETWEEN 0.4 AND 0.6 THEN 'DISTRIBUCIÓN_BALANCEADA'
        WHEN AVG(cSeleccion) < 0.8 THEN 'PREDOMINIO_1_MODERADO'
        ELSE 'PREDOMINIO_1_FUERTE'
    END
FROM productos_t3 WHERE cIDT IN (@O01, @O02)

ORDER BY trimestre;

-- ====================================================================
-- ANÁLISIS ESTADÍSTICO PARA VARIABLES BINARIAS - cIOT
-- ====================================================================

SELECT 'SUMMARY ESTADÍSTICO - VARIABLE BINARIA cIOT' as proceso_iot;

-- Análisis específico para variable binaria cIOT (misma estructura que cSeleccion)
SELECT 
    @Q1_nombre as trimestre,
    'cIOT' as variable,
    COUNT(*) as n_total,
    COUNT(cIOT) as n_validos,
    COUNT(*) - COUNT(cIOT) as n_nulos,
    ROUND((COUNT(cIOT) * 100.0 / COUNT(*)), 2) as completitud_pct,
    
    MIN(cIOT) as valor_minimo,
    MAX(cIOT) as valor_maximo,
    COUNT(CASE WHEN cIOT = 0 THEN 1 END) as frecuencia_0,
    COUNT(CASE WHEN cIOT = 1 THEN 1 END) as frecuencia_1,
    ROUND((COUNT(CASE WHEN cIOT = 0 THEN 1 END) * 100.0 / COUNT(cIOT)), 2) as porcentaje_0,
    ROUND((COUNT(CASE WHEN cIOT = 1 THEN 1 END) * 100.0 / COUNT(cIOT)), 2) as porcentaje_1,
    ROUND(AVG(cIOT), 4) as proporcion_media_1,
    ROUND(STDDEV(cIOT), 4) as desviacion_estandar,
    ROUND(VARIANCE(cIOT), 4) as varianza,
    
    CASE 
        WHEN COUNT(CASE WHEN cIOT = 1 THEN 1 END) > COUNT(CASE WHEN cIOT = 0 THEN 1 END) THEN 1
        WHEN COUNT(CASE WHEN cIOT = 0 THEN 1 END) > COUNT(CASE WHEN cIOT = 1 THEN 1 END) THEN 0
        ELSE 'BIMODAL'
    END as moda,
    
    CASE 
        WHEN AVG(cIOT) < 0.1 THEN 'PREDOMINIO_0_FUERTE'
        WHEN AVG(cIOT) < 0.3 THEN 'PREDOMINIO_0_MODERADO'
        WHEN AVG(cIOT) BETWEEN 0.4 AND 0.6 THEN 'DISTRIBUCIÓN_BALANCEADA'
        WHEN AVG(cIOT) < 0.8 THEN 'PREDOMINIO_1_MODERADO'
        ELSE 'PREDOMINIO_1_FUERTE'
    END as clasificacion_distribucion
    
FROM productos_t1 
WHERE cIDT IN (@O01, @O02)

UNION ALL

SELECT 
    @Q2_nombre, 'cIOT', COUNT(*), COUNT(cIOT), COUNT(*) - COUNT(cIOT),
    ROUND((COUNT(cIOT) * 100.0 / COUNT(*)), 2),
    MIN(cIOT), MAX(cIOT),
    COUNT(CASE WHEN cIOT = 0 THEN 1 END), COUNT(CASE WHEN cIOT = 1 THEN 1 END),
    ROUND((COUNT(CASE WHEN cIOT = 0 THEN 1 END) * 100.0 / COUNT(cIOT)), 2),
    ROUND((COUNT(CASE WHEN cIOT = 1 THEN 1 END) * 100.0 / COUNT(cIOT)), 2),
    ROUND(AVG(cIOT), 4), ROUND(STDDEV(cIOT), 4), ROUND(VARIANCE(cIOT), 4),
    
    CASE 
        WHEN COUNT(CASE WHEN cIOT = 1 THEN 1 END) > COUNT(CASE WHEN cIOT = 0 THEN 1 END) THEN 1
        WHEN COUNT(CASE WHEN cIOT = 0 THEN 1 END) > COUNT(CASE WHEN cIOT = 1 THEN 1 END) THEN 0
        ELSE 'BIMODAL'
    END,
    
    CASE 
        WHEN AVG(cIOT) < 0.1 THEN 'PREDOMINIO_0_FUERTE'
        WHEN AVG(cIOT) < 0.3 THEN 'PREDOMINIO_0_MODERADO'
        WHEN AVG(cIOT)