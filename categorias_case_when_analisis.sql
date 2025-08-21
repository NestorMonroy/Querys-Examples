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
     Script          : Análisis 3 - Categorías con CASE WHEN (Elegante y Completo)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - CASE WHEN para limpiar categorías vacías/problemáticas
     - Muestra panorama completo: registros buenos Y problemáticos
     - KISS: Keep It Simple, Stupid
     - Más elegante y flexible que WHERE filters
     
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
-- ANÁLISIS: CATEGORÍAS CON CASE WHEN (ELEGANTE Y COMPLETO)
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: CATEGORÍAS CON LIMPIEZA CASE WHEN' as proceso;

-- Análisis completo con CASE WHEN para limpiar categorías
SELECT 
    CASE 
        WHEN cIDR = @OP THEN 'OP'
        WHEN cIDR = @ONa THEN 'ONa'
    END as organizacion,
    trimestre,
    CASE 
        WHEN categoria = '' THEN 'vacio'
        WHEN categoria = 'sin categoria' THEN 'vacio'
        WHEN categoria IS NULL THEN 'vacio'
        WHEN TRIM(categoria) = '' THEN 'vacio'
        ELSE UPPER(TRIM(categoria))  -- Limpiar y estandarizar categorías válidas
    END as categoria_limpia,
    COUNT(*) as cantidad_registros
FROM (
    SELECT @Q1_nombre as trimestre, cIDR, categoria
    FROM ventas_1
    WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    SELECT @Q2_nombre as trimestre, cIDR, categoria
    FROM ventas_2
    WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    SELECT @Q3_nombre as trimestre, cIDR, categoria
    FROM ventas_3
    WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
    AND cIDR IN (@OP, @ONa)
) datos_consolidados
GROUP BY cIDR, trimestre, categoria_limpia
ORDER BY 
    CASE WHEN cIDR = @OP THEN 1 ELSE 2 END,
    CASE trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
    END,
    cantidad_registros DESC;

-- ====================================================================
-- FINALIZACIÓN
-- ====================================================================

SELECT '<<< ANÁLISIS CATEGORÍAS CON CASE WHEN COMPLETADO >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'CASE_WHEN_ELEGANTE' as tecnica_utilizada,
    NOW() as timestamp_fin
FROM DUAL;