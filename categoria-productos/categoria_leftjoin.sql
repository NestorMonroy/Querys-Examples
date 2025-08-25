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
     Script          : Análisis 3B - Categoría No Comprada - LEFT JOIN (Elegante)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - Versión ELEGANTE usando LEFT JOIN
     - Patrón SQL estándar muy común
     - Declarativo: Describes WHAT, no HOW
     - Optimizable por el motor de base de datos
     
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
-- ANÁLISIS: CATEGORÍAS CON LEFT JOIN (ELEGANTE)
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: CATEGORÍAS CON LEFT JOIN (ELEGANTE)' as proceso;

WITH todas_las_categorias AS (
    SELECT DISTINCT categoria
    FROM (
        SELECT categoria FROM ventas_1
        WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
        AND cIDR IN (@OP, @ONa)

        UNION

        SELECT categoria FROM ventas_2
        WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
        AND cIDR IN (@OP, @ONa)

        UNION

        SELECT categoria FROM ventas_3
        WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
        AND cIDR IN (@OP, @ONa)
    ) categorias_totales
),
todos_los_trimestres AS (
    SELECT @Q1_nombre as trimestre
    UNION ALL
    SELECT @Q2_nombre
    UNION ALL
    SELECT @Q3_nombre
),
categorias_activas AS (
    SELECT DISTINCT @Q1_nombre as trimestre, categoria
    FROM ventas_1
    WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    SELECT DISTINCT @Q2_nombre as trimestre, categoria
    FROM ventas_2
    WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    SELECT DISTINCT @Q3_nombre as trimestre, categoria
    FROM ventas_3
    WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
    AND cIDR IN (@OP, @ONa)
)
-- LEFT JOIN elegante: Universo completo vs Activas
SELECT 
    universo.trimestre,
    universo.categoria,
    CASE 
        WHEN activas.categoria IS NOT NULL THEN 'vacia'
        ELSE 'no comprada'
    END as estado
FROM (
    -- Crear universo completo: Todas categorías x Todos trimestres
    SELECT t.trimestre, c.categoria
    FROM todas_las_categorias c
    CROSS JOIN todos_los_trimestres t
) universo
LEFT JOIN categorias_activas activas
    ON universo.trimestre = activas.trimestre
    AND universo.categoria = activas.categoria
ORDER BY 
    CASE universo.trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
    END,
    universo.categoria;

-- ====================================================================
-- FINALIZACIÓN
-- ====================================================================

SELECT '<<< ANÁLISIS CATEGORÍAS CON LEFT JOIN COMPLETADO >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'LEFT JOIN - PATRÓN SQL ESTÁNDAR' as metodo_elegante,
    NOW() as timestamp_fin
FROM DUAL;