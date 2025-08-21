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
     Script          : Análisis 3C - Categoría No Comprada - WINDOW FUNCTION (Elegante)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - Versión ELEGANTE usando WINDOW FUNCTIONS
     - Enfoque analítico moderno
     - Una sola pasada con cálculos avanzados
     - Uso de CASE con agregaciones window
     
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
-- ANÁLISIS: CATEGORÍAS CON WINDOW FUNCTION (ELEGANTE)
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS: CATEGORÍAS CON WINDOW FUNCTION (ELEGANTE)' as proceso;

WITH datos_consolidados AS (
    SELECT @Q1_nombre as trimestre, categoria
    FROM ventas_1
    WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    SELECT @Q2_nombre as trimestre, categoria
    FROM ventas_2
    WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
    AND cIDR IN (@OP, @ONa)

    UNION ALL

    SELECT @Q3_nombre as trimestre, categoria
    FROM ventas_3
    WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
    AND cIDR IN (@OP, @ONa)
),
universo_completo AS (
    SELECT DISTINCT
        t.trimestre,
        c.categoria,
        -- Window function: ¿Esta categoría aparece en este trimestre?
        SUM(CASE 
            WHEN d.trimestre = t.trimestre AND d.categoria = c.categoria THEN 1 
            ELSE 0 
        END) OVER (
            PARTITION BY t.trimestre, c.categoria
        ) as apariciones_en_trimestre
    FROM (
        -- Todos los trimestres
        SELECT @Q1_nombre as trimestre
        UNION ALL SELECT @Q2_nombre
        UNION ALL SELECT @Q3_nombre
    ) t
    CROSS JOIN (
        -- Todas las categorías que existen
        SELECT DISTINCT categoria FROM datos_consolidados
    ) c
    LEFT JOIN datos_consolidados d ON 1=1  -- Cartesian para window function
)
SELECT 
    trimestre,
    categoria,
    CASE 
        WHEN apariciones_en_trimestre > 0 THEN 'vacia'
        ELSE 'no comprada'
    END as estado
FROM universo_completo
GROUP BY trimestre, categoria, apariciones_en_trimestre
ORDER BY 
    CASE trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
    END,
    categoria;

-- ====================================================================
-- VERSIÓN ALTERNATIVA: WINDOW CON DENSE_RANK
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS ALTERNATIVO: WINDOW CON DENSE_RANK' as proceso;

WITH datos_base AS (
    SELECT trimestre, categoria
    FROM (
        SELECT @Q1_nombre as trimestre, categoria FROM ventas_1
        WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
        AND cIDR IN (@OP, @ONa)

        UNION ALL

        SELECT @Q2_nombre as trimestre, categoria FROM ventas_2
        WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
        AND cIDR IN (@OP, @ONa)

        UNION ALL

        SELECT @Q3_nombre as trimestre, categoria FROM ventas_3
        WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
        AND cIDR IN (@OP, @ONa)
    ) consolidado
),
categoria_presence AS (
    SELECT DISTINCT
        universo.trimestre,
        universo.categoria,
        -- Window function elegante: Ranking de presencia
        DENSE_RANK() OVER (
            PARTITION BY universo.trimestre, universo.categoria 
            ORDER BY CASE WHEN activas.categoria IS NOT NULL THEN 1 ELSE 2 END
        ) as ranking_presencia
    FROM (
        SELECT t.trimestre, c.categoria
        FROM (SELECT @Q1_nombre UNION ALL SELECT @Q2_nombre UNION ALL SELECT @Q3_nombre) t(trimestre)
        CROSS JOIN (SELECT DISTINCT categoria FROM datos_base) c(categoria)
    ) universo
    LEFT JOIN datos_base activas 
        ON universo.trimestre = activas.trimestre 
        AND universo.categoria = activas.categoria
)
SELECT 
    trimestre,
    categoria,
    CASE 
        WHEN ranking_presencia = 1 AND EXISTS (
            SELECT 1 FROM datos_base db 
            WHERE db.trimestre = categoria_presence.trimestre 
            AND db.categoria = categoria_presence.categoria
        ) THEN 'vacia'
        ELSE 'no comprada'
    END as estado
FROM categoria_presence
ORDER BY 
    CASE trimestre
        WHEN @Q1_nombre THEN 1
        WHEN @Q2_nombre THEN 2
        WHEN @Q3_nombre THEN 3
    END,
    categoria;

-- ====================================================================
-- FINALIZACIÓN
-- ====================================================================

SELECT '<<< ANÁLISIS CATEGORÍAS CON WINDOW FUNCTION COMPLETADO >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'WINDOW FUNCTION - ANALÍTICA MODERNA' as metodo_elegante,
    NOW() as timestamp_fin
FROM DUAL;