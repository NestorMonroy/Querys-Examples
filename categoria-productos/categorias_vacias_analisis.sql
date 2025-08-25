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
     Script          : Análisis 3 - Categorías No Compradas (Registros Sin Categoría)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - Identifica registros con categoría vacía, nula o 'sin categoria'
     - GROUP BY + COUNT(*) para eficiencia
     - KISS: Keep It Simple, Stupid
     - Análisis de calidad de datos
     
*********************************************************************************************/

-- ====================================================================
-- CONFIGURACIÓN DE VARIABLES
-- ====================================================================

SET @OP = 123;
SET @ONa = 369;

SET @Q1_nombre = 'Q01_25';
SET @Q1_inicio = '2025-01-01';
SET @Q1_fin = '2025-03-31';

SET @Q2_nombre = 'Q02_25';
SET @Q2_inicio = '2025-04-01';
SET @Q2_fin = '2025-06-30';

SET @Q3_nombre = 'Q03_25';
SET @Q3_inicio = '2025-07-01';
SET @Q3_fin = '2025-09-30';

-- Mostrar configuración
SELECT 
    'CONFIGURACIÓN DE VARIABLES' as seccion
    , @OP
    , @ONa 
    , @Q1_nombre
    , @Q1_inicio
    , @Q1_fin
    , @Q2_nombre
    , @Q2_inicio
    , @Q2_fin
    , @Q3_nombre
    , @Q3_inicio
    , @Q3_fin;

-- ====================================================================
-- ANÁLISIS: CATEGORÍAS NO COMPRADAS (REGISTROS SIN CATEGORÍA)
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: REGISTROS SIN CATEGORÍA - CALIDAD DE DATOS' as proceso;

-- Conteo simple de registros con categoría vacía/nula
SELECT 
    CASE 
        WHEN cIDR = @OP THEN 'OP'
        WHEN cIDR = @ONa THEN 'ONa'
    END as organizacion,
    trimestre,
    COUNT(*) as registros_sin_categoria
FROM (
    SELECT @Q1_nombre as trimestre, cIDR
    FROM ventas_1
    WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
    AND cIDR IN (@OP, @ONa)
    AND (
        categoria = '' 
        OR categoria = 'sin categoria' 
        OR categoria IS NULL
        OR TRIM(categoria) = ''
    )

    UNION ALL

    SELECT @Q2_nombre as trimestre, cIDR
    FROM ventas_2
    WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
    AND cIDR IN (@OP, @ONa)
    AND (
        categoria = '' 
        OR categoria = 'sin categoria' 
        OR categoria IS NULL
        OR TRIM(categoria) = ''
    )

    UNION ALL

    SELECT @Q3_nombre as trimestre, cIDR
    FROM ventas_3
    WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
    AND cIDR IN (@OP, @ONa)
    AND (
        categoria = '' 
        OR categoria = 'sin categoria' 
        OR categoria IS NULL
        OR TRIM(categoria) = ''
    )
) registros_problematicos
GROUP BY cIDR, trimestre
ORDER BY 
    CASE WHEN cIDR = @OP THEN 1 ELSE 2 END,
    CASE trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
    END;

-- ====================================================================
-- FINALIZACIÓN
-- ====================================================================

SELECT '<<< ANÁLISIS REGISTROS SIN CATEGORÍA COMPLETADO >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'CALIDAD_DE_DATOS' as tipo_analisis,
    NOW() as timestamp_fin
FROM DUAL;