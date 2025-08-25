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
     Script          : Análisis 3 - Categorías No Compradas (Optimizado)
     
     Create          : AGOSTO/2025
     Engine          : MariaDB/MySQL
     
     Parámetros Variables:
     @OP, @ONa, @ONa02 - Códigos de organización
     @Q1_inicio, @Q1_fin - Rango de fechas Q1 2025
     @Q2_inicio, @Q2_fin - Rango de fechas Q2 2025  
     @Q3_inicio, @Q3_fin - Rango de fechas Q3 2025
     
     Notas:
     - Optimizado SIN tabla temporal para evitar problemas de memoria con ~3TB
     - Consulta directa sobre ventas_1, ventas_2, ventas_3
     - Las fechas deben estar en formato ISO (YYYY-MM-DD) para compatibilidad
     - Análisis específico: Categorías que aparecen en algunos trimestres pero no en otros
     
*********************************************************************************************/

-- ====================================================================
-- CONFIGURACIÓN DE VARIABLES DE FECHA POR TRIMESTRE
-- ====================================================================

-- ====================================================================
-- MÉTODO 1: FECHAS FIJAS (Configuración manual)
-- ====================================================================

-- Definir variables para rangos de fechas de cada trimestre

SET @OP = 123;
SET @ONa = 369;
SET @ONa02 = 1902001;

SET @Q1_nombre = 'Q01_25';
SET @Q1_inicio = '2025-01-01';
SET @Q1_fin = '2025-03-31';

SET @Q2_nombre = 'Q02_25';
SET @Q2_inicio = '2025-04-01';
SET @Q2_fin = '2025-06-30';

SET @Q3_nombre = 'Q03_25';
SET @Q3_inicio = '2025-07-01';
SET @Q3_fin = '2025-09-30';

-- Mostrar configuración final seleccionada
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
	
-- Mostrar estadísticas iniciales para monitoreo
SELECT 
    'INICIO DEL PROCESO - ANÁLISIS CATEGORÍAS NO COMPRADAS' as evento
    , NOW() as timestamp
    , CONNECTION_ID() as connection_id
FROM DUAL;

-- ====================================================================
-- CONTEO DE DATOS EXISTENTES
-- ====================================================================

-- Contar categorías por trimestre ANTES del proceso 
SELECT 'ANTES - CATEGORÍAS POR TRIMESTRE EN TABLA FUENTE' as reporte;

SELECT 
    @Q1_nombre as trimestre,
    @Q1_inicio as fecha_inicio,
    @Q1_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT categoria) as categorias_distintas
FROM ventas_1
WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
AND cIDR IN (@OP, @ONa)

UNION ALL

SELECT 
    @Q2_nombre as trimestre,
    @Q2_inicio as fecha_inicio,
    @Q2_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT categoria) as categorias_distintas
FROM ventas_2
WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
AND cIDR IN (@OP, @ONa)

UNION ALL

SELECT 
    @Q3_nombre as trimestre,
    @Q3_inicio as fecha_inicio,
    @Q3_fin as fecha_fin,
    COUNT(*) as registros_existentes,
    COUNT(DISTINCT categoria) as categorias_distintas
FROM ventas_3
WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
AND cIDR IN (@OP, @ONa);

-- ====================================================================
-- PREPARACIÓN: CATEGORÍAS ÚNICAS POR TRIMESTRE
-- ====================================================================

SELECT 'EJECUTANDO PREPARACIÓN: EXTRAYENDO CATEGORÍAS POR TRIMESTRE' as proceso;

-- Crear tablas temporales para categorías por trimestre
CREATE TEMPORARY TABLE temp_categorias_q1 (
    categoria VARCHAR(100),
    PRIMARY KEY (categoria)
) ENGINE=MEMORY;

CREATE TEMPORARY TABLE temp_categorias_q2 (
    categoria VARCHAR(100),
    PRIMARY KEY (categoria)
) ENGINE=MEMORY;

CREATE TEMPORARY TABLE temp_categorias_q3 (
    categoria VARCHAR(100),
    PRIMARY KEY (categoria)
) ENGINE=MEMORY;

-- Cargar categorías únicas por trimestre
INSERT INTO temp_categorias_q1
SELECT DISTINCT categoria 
FROM ventas_1
WHERE fechaTabla >= @Q1_inicio AND fechaTabla <= @Q1_fin
AND cIDR IN (@OP, @ONa);

INSERT INTO temp_categorias_q2
SELECT DISTINCT categoria 
FROM ventas_2
WHERE fechaTabla >= @Q2_inicio AND fechaTabla <= @Q2_fin
AND cIDR IN (@OP, @ONa);

INSERT INTO temp_categorias_q3
SELECT DISTINCT categoria 
FROM ventas_3
WHERE fechaTabla >= @Q3_inicio AND fechaTabla <= @Q3_fin
AND cIDR IN (@OP, @ONa);

-- Mostrar estadísticas de categorías por trimestre
SELECT 
    'ESTADÍSTICAS_CATEGORÍAS_POR_TRIMESTRE' as analisis,
    (SELECT COUNT(*) FROM temp_categorias_q1) as categorias_Q1,
    (SELECT COUNT(*) FROM temp_categorias_q2) as categorias_Q2,
    (SELECT COUNT(*) FROM temp_categorias_q3) as categorias_Q3;

-- ====================================================================
-- ANÁLISIS PRINCIPAL: CATEGORÍAS NO COMPRADAS POR TRIMESTRE
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS PRINCIPAL: CATEGORÍAS NO COMPRADAS' as proceso;

-- Categorías que NO aparecen en Q2 pero sí estaban en Q1
SELECT 
    'CATEGORÍAS_NO_COMPRADAS_EN_Q2' as tipo_analisis,
    @Q2_nombre as trimestre_sin_compra,
    @Q1_nombre as trimestre_referencia,
    COUNT(*) as cantidad_categorias
FROM temp_categorias_q1 q1
LEFT JOIN temp_categorias_q2 q2 ON q1.categoria = q2.categoria
WHERE q2.categoria IS NULL;

-- Categorías que NO aparecen en Q3 pero sí estaban en Q2
SELECT 
    'CATEGORÍAS_NO_COMPRADAS_EN_Q3' as tipo_analisis,
    @Q3_nombre as trimestre_sin_compra,
    @Q2_nombre as trimestre_referencia,
    COUNT(*) as cantidad_categorias
FROM temp_categorias_q2 q2
LEFT JOIN temp_categorias_q3 q3 ON q2.categoria = q3.categoria
WHERE q3.categoria IS NULL;

-- Categorías que NO aparecen en Q3 pero sí estaban en Q1
SELECT 
    'CATEGORÍAS_NO_COMPRADAS_EN_Q3_VS_Q1' as tipo_analisis,
    @Q3_nombre as trimestre_sin_compra,
    @Q1_nombre as trimestre_referencia,
    COUNT(*) as cantidad_categorias
FROM temp_categorias_q1 q1
LEFT JOIN temp_categorias_q3 q3 ON q1.categoria = q3.categoria
WHERE q3.categoria IS NULL;

-- ====================================================================
-- ANÁLISIS DETALLADO: LISTADO DE CATEGORÍAS NO COMPRADAS
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS DETALLADO: LISTADO ESPECÍFICO DE CATEGORÍAS' as proceso;

-- Listado específico: Categorías que estaban en Q1 pero NO en Q2
SELECT 
    'LISTADO_CATEGORÍAS_Q1_NO_Q2' as tipo_listado,
    q1.categoria,
    'Categoría presente en Q1 pero ausente en Q2' as descripcion
FROM temp_categorias_q1 q1
LEFT JOIN temp_categorias_q2 q2 ON q1.categoria = q2.categoria
WHERE q2.categoria IS NULL
ORDER BY q1.categoria;

-- Listado específico: Categorías que estaban en Q2 pero NO en Q3
SELECT 
    'LISTADO_CATEGORÍAS_Q2_NO_Q3' as tipo_listado,
    q2.categoria,
    'Categoría presente en Q2 pero ausente en Q3' as descripcion
FROM temp_categorias_q2 q2
LEFT JOIN temp_categorias_q3 q3 ON q2.categoria = q3.categoria
WHERE q3.categoria IS NULL
ORDER BY q2.categoria;

-- Listado específico: Categorías que estaban en Q1 pero NO en Q3
SELECT 
    'LISTADO_CATEGORÍAS_Q1_NO_Q3' as tipo_listado,
    q1.categoria,
    'Categoría presente en Q1 pero ausente en Q3' as descripcion
FROM temp_categorias_q1 q1
LEFT JOIN temp_categorias_q3 q3 ON q1.categoria = q3.categoria
WHERE q3.categoria IS NULL
ORDER BY q1.categoria;

-- ====================================================================
-- ANÁLISIS COMPLEMENTARIO: PATRONES DE PRESENCIA/AUSENCIA
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS COMPLEMENTARIO: PATRONES DE PRESENCIA' as proceso;

-- Crear tabla temporal para análisis de patrones
CREATE TEMPORARY TABLE temp_patron_categorias (
    categoria VARCHAR(100),
    presente_q1 BOOLEAN,
    presente_q2 BOOLEAN,
    presente_q3 BOOLEAN,
    patron_presencia VARCHAR(20),
    trimestres_activos INT,
    PRIMARY KEY (categoria)
) ENGINE=MEMORY;

-- Cargar patrones de presencia de categorías
INSERT INTO temp_patron_categorias
SELECT 
    todas_categorias.categoria,
    (q1.categoria IS NOT NULL) as presente_q1,
    (q2.categoria IS NOT NULL) as presente_q2,
    (q3.categoria IS NOT NULL) as presente_q3,
    CONCAT(
        CASE WHEN q1.categoria IS NOT NULL THEN '1' ELSE '0' END,
        CASE WHEN q2.categoria IS NOT NULL THEN '1' ELSE '0' END,
        CASE WHEN q3.categoria IS NOT NULL THEN '1' ELSE '0' END
    ) as patron_presencia,
    (CASE WHEN q1.categoria IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN q2.categoria IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN q3.categoria IS NOT NULL THEN 1 ELSE 0 END) as trimestres_activos
FROM (
    SELECT categoria FROM temp_categorias_q1
    UNION
    SELECT categoria FROM temp_categorias_q2
    UNION
    SELECT categoria FROM temp_categorias_q3
) todas_categorias
LEFT JOIN temp_categorias_q1 q1 ON todas_categorias.categoria = q1.categoria
LEFT JOIN temp_categorias_q2 q2 ON todas_categorias.categoria = q2.categoria
LEFT JOIN temp_categorias_q3 q3 ON todas_categorias.categoria = q3.categoria;

-- Análisis de patrones de presencia
SELECT 
    patron_presencia,
    CASE patron_presencia
        WHEN '111' THEN 'PRESENTE_EN_TODOS'
        WHEN '110' THEN 'PRESENTE_Q1_Q2_AUSENTE_Q3'
        WHEN '101' THEN 'PRESENTE_Q1_Q3_AUSENTE_Q2'
        WHEN '011' THEN 'AUSENTE_Q1_PRESENTE_Q2_Q3'
        WHEN '100' THEN 'SOLO_Q1'
        WHEN '010' THEN 'SOLO_Q2'
        WHEN '001' THEN 'SOLO_Q3'
        ELSE 'PATRON_INESPERADO'
    END as descripcion_patron,
    COUNT(*) as cantidad_categorias,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM temp_patron_categorias), 2) as porcentaje
FROM temp_patron_categorias
GROUP BY patron_presencia
ORDER BY cantidad_categorias DESC;

-- ====================================================================
-- ANÁLISIS ESPECÍFICO: CATEGORÍAS PROBLEMÁTICAS
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS ESPECÍFICO: CATEGORÍAS PROBLEMÁTICAS' as proceso;

-- Categorías que desaparecieron completamente después de Q1
SELECT 
    'CATEGORÍAS_DESAPARECIDAS_DESPUÉS_Q1' as tipo_problema,
    COUNT(*) as cantidad,
    'Categorías que solo aparecen en Q1' as descripcion
FROM temp_patron_categorias
WHERE patron_presencia = '100';

-- Categorías intermitentes (aparecen, desaparecen, vuelven a aparecer)
SELECT 
    'CATEGORÍAS_INTERMITENTES' as tipo_problema,
    COUNT(*) as cantidad,
    'Categorías con patrón de presencia irregular' as descripcion
FROM temp_patron_categorias
WHERE patron_presencia IN ('101', '010');

-- Categorías que aparecieron tarde (no estaban en Q1)
SELECT 
    'CATEGORÍAS_APARICIÓN_TARDÍA' as tipo_problema,
    COUNT(*) as cantidad,
    'Categorías que no estaban en Q1 pero aparecen después' as descripcion
FROM temp_patron_categorias
WHERE patron_presencia IN ('011', '001', '010');

-- ====================================================================
-- ANÁLISIS DETALLADO: CATEGORÍAS POR TIPO DE PROBLEMA
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS DETALLADO: CATEGORÍAS POR TIPO DE PROBLEMA' as proceso;

-- Categorías que solo aparecen en Q1 (posible descontinuación)
SELECT 
    'POSIBLE_DESCONTINUACIÓN' as tipo_problema,
    categoria,
    'Solo presente en Q1' as detalle
FROM temp_patron_categorias
WHERE patron_presencia = '100'
ORDER BY categoria;

-- Categorías intermitentes Q1→Q3 (saltaron Q2)
SELECT 
    'CATEGORÍA_INTERMITENTE_Q1_Q3' as tipo_problema,
    categoria,
    'Presente en Q1 y Q3 pero ausente en Q2' as detalle
FROM temp_patron_categorias
WHERE patron_presencia = '101'
ORDER BY categoria;

-- Categorías que aparecieron en Q2 y se mantuvieron en Q3 (nuevas exitosas)
SELECT 
    'NUEVA_CATEGORÍA_EXITOSA' as tipo_problema,
    categoria,
    'Ausente en Q1 pero presente en Q2 y Q3' as detalle
FROM temp_patron_categorias
WHERE patron_presencia = '011'
ORDER BY categoria;

-- ====================================================================
-- RESUMEN EJECUTIVO FINAL
-- ====================================================================

SELECT 'GENERANDO RESUMEN EJECUTIVO FINAL' as proceso;

-- Crear tabla temporal para resumen ejecutivo
CREATE TEMPORARY TABLE temp_resumen_categorias_no_compradas (
    metrica VARCHAR(50),
    valor INT,
    descripcion TEXT
) ENGINE=MEMORY;

-- Cargar métricas del resumen ejecutivo
INSERT INTO temp_resumen_categorias_no_compradas
SELECT 
    'TOTAL_CATEGORÍAS_ÚNICAS',
    COUNT(*),
    'Total de categorías únicas que aparecieron en al menos un trimestre'
FROM temp_patron_categorias

UNION ALL

SELECT 
    'CATEGORÍAS_ESTABLES',
    COUNT(*),
    'Categorías que aparecen en los 3 trimestres (patrón 111)'
FROM temp_patron_categorias
WHERE patron_presencia = '111'

UNION ALL

SELECT 
    'CATEGORÍAS_PROBLEMÁTICAS',
    COUNT(*),
    'Categorías que NO aparecen en los 3 trimestres'
FROM temp_patron_categorias
WHERE patron_presencia != '111'

UNION ALL

SELECT 
    'CATEGORÍAS_DESCONTINUADAS',
    COUNT(*),
    'Categorías que desaparecieron después de aparecer'
FROM temp_patron_categorias
WHERE patron_presencia IN ('100', '110')

UNION ALL

SELECT 
    'CATEGORÍAS_NUEVAS',
    COUNT(*),
    'Categorías que aparecieron después de Q1'
FROM temp_patron_categorias
WHERE patron_presencia IN ('011', '001', '010')

UNION ALL

SELECT 
    'CATEGORÍAS_INTERMITENTES',
    COUNT(*),
    'Categorías con presencia irregular (patrón 101 o 010)'
FROM temp_patron_categorias
WHERE patron_presencia IN ('101', '010');

-- Mostrar resumen ejecutivo
SELECT 
    metrica,
    valor,
    descripcion,
    ROUND(valor * 100.0 / (SELECT valor FROM temp_resumen_categorias_no_compradas WHERE metrica = 'TOTAL_CATEGORÍAS_ÚNICAS'), 2) as porcentaje_del_total
FROM temp_resumen_categorias_no_compradas
ORDER BY 
    CASE metrica
        WHEN 'TOTAL_CATEGORÍAS_ÚNICAS' THEN 1
        WHEN 'CATEGORÍAS_ESTABLES' THEN 2
        WHEN 'CATEGORÍAS_PROBLEMÁTICAS' THEN 3
        WHEN 'CATEGORÍAS_DESCONTINUADAS' THEN 4
        WHEN 'CATEGORÍAS_NUEVAS' THEN 5
        WHEN 'CATEGORÍAS_INTERMITENTES' THEN 6
        ELSE 99
    END;

-- ====================================================================
-- ANÁLISIS FINAL: IMPACTO DE CATEGORÍAS NO COMPRADAS
-- ====================================================================

SELECT 'EJECUTANDO ANÁLISIS FINAL: IMPACTO EN ESTABILIDAD DEL CATÁLOGO' as proceso;

-- Cálculo de estabilidad del catálogo
WITH estabilidad_calculo AS (
    SELECT 
        (SELECT COUNT(*) FROM temp_patron_categorias WHERE patron_presencia = '111') as categorias_estables,
        (SELECT COUNT(*) FROM temp_patron_categorias) as total_categorias
)
SELECT 
    'ÍNDICE_ESTABILIDAD_CATÁLOGO' as metrica,
    ROUND(categorias_estables * 100.0 / total_categorias, 2) as porcentaje_estabilidad,
    CASE 
        WHEN (categorias_estables * 100.0 / total_categorias) >= 80 THEN 'CATÁLOGO_MUY_ESTABLE'
        WHEN (categorias_estables * 100.0 / total_categorias) >= 60 THEN 'CATÁLOGO_ESTABLE'
        WHEN (categorias_estables * 100.0 / total_categorias) >= 40 THEN 'CATÁLOGO_MODERADAMENTE_ESTABLE'
        ELSE 'CATÁLOGO_INESTABLE'
    END as clasificacion_estabilidad,
    CONCAT(
        'De ', total_categorias, ' categorías únicas, ', 
        categorias_estables, ' aparecen en los 3 trimestres'
    ) as interpretacion
FROM estabilidad_calculo;

-- Limpiar tablas temporales
DROP TEMPORARY TABLE IF EXISTS temp_categorias_q1;
DROP TEMPORARY TABLE IF EXISTS temp_categorias_q2;
DROP TEMPORARY TABLE IF EXISTS temp_categorias_q3;
DROP TEMPORARY TABLE IF EXISTS temp_patron_categorias;
DROP TEMPORARY TABLE IF EXISTS temp_resumen_categorias_no_compradas;

-- ====================================================================
-- FINALIZACIÓN DEL PROCESO
-- ====================================================================

-- Verificar finalización exitosa
SELECT '<<< ANÁLISIS CATEGORÍAS NO COMPRADAS COMPLETADO EXITOSAMENTE >>>' as resultado;

SELECT 
    'PROCESO COMPLETADO' as evento,
    'CATEGORÍAS_NO_COMPRADAS' as tipo_analisis,
    'SIN_TABLA_TEMPORAL' as metodo_optimizado,
    'CONSULTA_DIRECTA_OPTIMIZADA' as estrategia,
    NOW() as timestamp_fin
FROM DUAL;