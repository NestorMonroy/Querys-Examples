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
     Script          : Análisis 2 - Promedio de Productos (KISS)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - Optimizado SIN tabla temporal (evita ~3TB en memoria)
     - Consulta directa sobre ventas_1, ventas_2, ventas_3
     - KISS: Keep It Simple, Stupid
     - Matriz cIDR vs Categoría: Comparación @OP vs @ONa
     
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
-- ANÁLISIS: PROMEDIO DE PRODUCTOS - MATRIZ cIDR vs CATEGORÍA
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: PROMEDIO DE PRODUCTOS - MATRIZ cIDR vs CATEGORÍA' as proceso;

-- Consulta directa sin tabla temporal - Matriz comparativa
SELECT 
    categoria,
    ROUND(AVG(CASE WHEN cIDR = @OP THEN productos_por_trimestre END), 2) as promedio_OP,
    ROUND(AVG(CASE WHEN cIDR = @ONa THEN productos_por_trimestre END), 2) as promedio_ONa,
    ROUND(
        AVG(CASE WHEN cIDR = @OP THEN productos_por_trimestre END) - 
        AVG(CASE WHEN cIDR = @ONa THEN productos_por_trimestre END), 2
    ) as diferencia_OP_minus_ONa
FROM (
    SELECT 
        categoria,
        cIDR,
        trimestre,
        COUNT(DISTINCT producto_id) as productos_por_trimestre
    FROM (
        SELECT @Q1_nombre as trimestre, categoria, cIDR, producto_id
        FROM ventas_1
        WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
        AND cIDR IN (@OP, @ONa)

        UNION ALL

        SELECT @Q2_nombre as trimestre, categoria, cIDR, producto_id
        FROM ventas_2
        WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
        AND cIDR IN (@OP, @ONa)

        UNION ALL

        SELECT @Q3_nombre as trimestre, categoria, cIDR, producto_id
        FROM ventas_3
        WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
        AND cIDR IN (@OP, @ONa)
    ) datos
    GROUP BY categoria, cIDR, trimestre
) productos_categoria_cidr_trimestre
GROUP BY categoria
HAVING promedio_OP IS NOT NULL OR promedio_ONa IS NOT NULL
ORDER BY 
    CASE 
        WHEN promedio_OP IS NOT NULL AND promedio_ONa IS NOT NULL 
        THEN ABS(diferencia_OP_minus_ONa)
        ELSE 0
    END DESC;

-- ====================================================================
-- FINALIZACIÓN
-- ====================================================================

SELECT '<<< ANÁLISIS PROMEDIO DE PRODUCTOS COMPLETADO >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    NOW() as timestamp_fin
FROM DUAL;