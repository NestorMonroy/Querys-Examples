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
     Script          : Análisis 3A - Categoría No Comprada - EXISTS (Elegante)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - Versión ELEGANTE usando EXISTS
     - Semántica clara: "¿Existe esta categoría en este trimestre?"
     - Performance optimizado: EXISTS se detiene en el primer match
     
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
-- ANÁLISIS: CATEGORÍAS CON EXISTS (ELEGANTE)
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: CATEGORÍAS CON EXISTS (ELEGANTE)' as proceso;

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
)
SELECT 
    t.trimestre,
    c.categoria,
    CASE 
        -- Q1: ¿Existe esta categoría en ventas_1?
        WHEN t.trimestre = @Q1_nombre AND EXISTS (
            SELECT 1 FROM ventas_1 v1
            WHERE v1.categoria = c.categoria
            AND v1.fechaTabla >= @Q1_inicio AND v1.fechaTabla <= @Q1_fin
            AND v1.cIDR IN (@OP, @ONa)
        ) THEN 'vacia'
        
        -- Q2: ¿Existe esta categoría en ventas_2?
        WHEN t.trimestre = @Q2_nombre AND EXISTS (
            SELECT 1 FROM ventas_2 v2
            WHERE v2.categoria = c.categoria
            AND v2.fechaTabla >= @Q2_inicio AND v2.fechaTabla <= @Q2_fin
            AND v2.cIDR IN (@OP, @ONa)
        ) THEN 'vacia'
        
        -- Q3: ¿Existe esta categoría en ventas_3?
        WHEN t.trimestre = @Q3_nombre AND EXISTS (
            SELECT 1 FROM ventas_3 v3
            WHERE v3.categoria = c.categoria
            AND v3.fechaTabla >= @Q3_inicio AND v3.fechaTabla <= @Q3_fin
            AND v3.cIDR IN (@OP, @ONa)
        ) THEN 'vacia'
        
        ELSE 'no comprada'
    END as estado
FROM todas_las_categorias c
CROSS JOIN todos_los_trimestres t
ORDER BY 
    CASE t.trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
    END,
    c.categoria;

-- ====================================================================
-- FINALIZACIÓN
-- ====================================================================

SELECT '<<< ANÁLISIS CATEGORÍAS CON EXISTS COMPLETADO >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'EXISTS - SEMÁNTICA CLARA' as metodo_elegante,
    NOW() as timestamp_fin
FROM DUAL;