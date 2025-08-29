# AS-IS: Interpretación de Data Real - Documento de Contexto

## Propósito del Documento
Este documento contextualiza la estructura y significado de los datos para informar la creación de reportes operacionales específicos, particularmente el reporte de promedio de interacciones por numero_entrada.

---

## 1. Interpretación de Campos Clave

### **Campos de Identificación:**
- **`numero_entrada`**: Usuario que inicia la interacción (entidad principal para promedios)
- **`numero_digitado`**: Número procesado internamente (puede diferir por lógica de negocio)
- **`idRe`**: Identificador único de cada registro de interacción

### **Campos de Navegación del Sistema:**
- **`menu`**: Menú del sistema donde ocurre la interacción
- **`opcion`**: Opción específica seleccionada dentro del menú
- **Relación**: menu + opcion determinan el tipo de interacción

### **Campos de Procesamiento:**
- **`etiquetas`**: Metadatos que indican el estado de procesamiento de la interacción
- **`id_CTransferencia`**: Destino real de redirección cuando aplica
- **`cIdentifica`**: Clave para vincular con otras tablas del sistema

### **Campos Organizacionales:**
- **`id_8T`**: Grupo de zonas geográficas
- **`division`**: División organizacional
- **`area`**: Área específica dentro de la división

### **Campos Temporales:**
- **`fecha`**: Fecha de la interacción
- **`hora_inicio/hora_fin`**: Tiempo de duración (almacenan solo hora, fecha base 01/01/1900)

---

## 2. Patrones de Comportamiento Identificados

### **Patrón 1: Usuario con Secuencia de Navegación Exitosa**
```
Ejemplo: numero_entrada = 2169010041
12:33:12 → Desborde_Cabecera [TELCO] → redirige a numero_digitado diferente
12:35:17 → RES-SP_2024 [DEFAULT] → procesamiento exitoso
12:45:31 → RES-SP_2024 [DEFAULT] → completación de servicio
Etiquetas: contienen "VSI,ZMB" = validación exitosa
```

### **Patrón 2: Usuario con Problemas del Sistema**
```
Ejemplo: numero_entrada = 2185530869  
17:35:52 → SinOpcion_Cbc (Sin opción disponible)
17:38:01 → cte_colgo (Cliente colgó)
17:40:40 → cte_colgo (Cliente colgó)
17:38:22 → Desborde_Cabecera + NoTmx_SOMC (Error sistema)
Etiquetas: "NoTmx_SOMC" o vacías = falla de procesamiento
```

### **Patrón 3: Usuario de Consulta Simple**
```
Ejemplo: menu = SDO, opcion = (vacía)
Duración corta, etiquetas mínimas
Una sola interacción por sesión
```

### **Patrón 4: Usuario Comercial**
```
Ejemplo: menu = comercial_5, opcion = 5
numero_digitado diferente (transferencia a área comercial)
Etiquetas pueden estar vacías (proceso directo)
```

---

## 3. Interpretación de Estados del Sistema

### **Estados de Validación (via etiquetas):**
- **"VSI,ZMB"**: Interacción validada y procesada por el sistema
- **"NOBOT"**: Confirmación de interacción humana real
- **"NoTmx_SOMC"**: Error del sistema, interacción no procesable
- **Vacío**: Interacción incompleta o falla de procesamiento

### **Estados de Menú:**
- **"RES-*"**: Servicios de resolución (alta probabilidad de éxito)
- **"comercial_*"**: Interacciones comerciales directas
- **"cte_colgo"**: Cliente abandonó (falla)
- **"SinOpcion_Cbc"**: Sistema no ofreció opciones válidas (falla)
- **"Desborde_*"**: Sistema en capacidad máxima

### **Redirecciones vs Procesamiento Interno:**
- **`id_CTransferencia` con valor**: Redirección real del sistema
- **`numero_entrada != numero_digitado`**: Procesamiento interno, no transferencia

---

## 4. Implicaciones para Cálculo de Promedios

### **Definición de "Interacción Válida":**
Cada registro representa una interacción del usuario con el sistema. Para el cálculo de promedios:

#### **Criterios de Inclusión Recomendados:**
1. **`numero_entrada` no nulo**: Debe existir el usuario
2. **`menu` no nulo**: Debe haber habido navegación real
3. **Excluir registros claramente fallidos**: Sin procesamiento del sistema

#### **Criterios de Calidad Sugeridos:**
- **Alta calidad**: etiquetas contienen "VSI" o "ZMB"
- **Calidad media**: menu válido pero etiquetas vacías
- **Baja calidad**: menu = "cte_colgo" o "SinOpcion_Cbc"

### **Agrupación Temporal:**
- **Por día**: Usar campo `fecha` directamente
- **Por usuario**: Agrupar por `numero_entrada` + `fecha`
- **Cálculo**: COUNT(*) registros / COUNT(DISTINCT numero_entrada) usuarios

---

## 5. Segmentación de Usuarios Identificada

### **Por Intensidad de Uso:**
- **Usuario Simple**: 1-2 interacciones por día
- **Usuario Moderado**: 3-5 interacciones por día  
- **Usuario Intensivo**: 6+ interacciones por día

### **Por Tipo de Interacción:**
- **Consulta Simple**: Solo SDO (saldo)
- **Servicios**: Principalmente RES-* 
- **Comercial**: Acceso a comercial_*
- **Problemático**: Alto % de cte_colgo/SinOpcion_Cbc

### **Por Validación del Sistema:**
- **Validado**: Alto % de etiquetas con VSI/ZMB
- **Parcial**: Algunos registros sin etiquetas
- **Fallido**: Predominio de etiquetas de error

---

## 6. Consideraciones para Análisis Temporal

### **Escalabilidad del Reporte:**
- **Diario**: Promedio directo por fecha
- **Semanal**: Agregación de promedios diarios de la semana
- **Mensual**: Considerando días laborables vs fines de semana
- **Anual**: Tendencias y estacionalidad

### **Factores que Afectan Promedios:**
- **Días con mantenimiento**: Picos de "Desborde_Cabecera"
- **Horarios operativos**: Variación por horas del día
- **Cambios del sistema**: Evolución entre trimestres

---

## 7. Limitaciones Actuales de los Datos

### **Calidad de Datos:**
- **Timestamps invertidos**: Requiere corrección para cálculos de duración
- **Campos nulos**: Impacta completitud del análisis
- **Consistencia de etiquetas**: No todos los registros siguen mismo patrón

### **Acceso a Información Completa:**
- **`cIdentifica`**: Referencias a tablas no disponibles actualmente
- **Contexto de redirecciones**: Información limitada sobre destinos
- **Historiales completos**: Solo disponibles 3 trimestres de 2025

---

## 8. Aplicación a Reporte Específico

### **Para el Reporte de Promedio de Interacciones:**

#### **Query Base Recomendado:**
```sql
SELECT 
    fecha,
    COUNT(DISTINCT numero_entrada) as usuarios_activos,
    COUNT(*) as total_interacciones,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada), 2) as promedio_interacciones_por_usuario
FROM (todas_las_tablas_trimestre)
WHERE numero_entrada IS NOT NULL 
  AND menu IS NOT NULL
GROUP BY fecha
ORDER BY fecha;
```

#### **Filtros Opcionales por Calidad:**
- **Solo validadas**: `AND etiquetas LIKE '%VSI%'`
- **Excluir fallidas**: `AND menu NOT IN ('cte_colgo', 'SinOpcion_Cbc')`
- **Solo con procesamiento completo**: `AND etiquetas IS NOT NULL AND etiquetas != ''`

#### **Segmentación Adicional:**
- Por zona geográfica (`id_8T`)
- Por división organizacional (`division`)
- Por tipo de usuario (basado en patrones de menú)

---

## 9. Análisis Adicionales Posibles

### **Análisis de Eficiencia:**
- Tasa de éxito por menú/opción
- Tiempo promedio por tipo de interacción
- Identificación de cuellos de botella del sistema

### **Análisis de Comportamiento:**
- Secuencias de navegación más comunes
- Patrones de abandono
- Segmentación de usuarios por perfil de uso

### **Análisis Operacional:**
- Distribución de carga por horario
- Capacidad del sistema (análisis de desborde)
- Evolución temporal de métricas

---

## 10. Recomendaciones para Reportes Futuros

### **Definiciones Estándar:**
1. Establecer criterios únicos para "interacción válida"
2. Definir períodos de reporte estándar
3. Crear baseline de calidad de datos

### **Mejoras de Proceso:**
1. Acceso a tablas relacionadas vía `cIdentifica`
2. Corrección sistemática de problemas de calidad
3. Documentación de cambios del sistema entre trimestres

### **Expansión de Análisis:**
1. Correlación con métricas de negocio
2. Análisis predictivo de comportamiento de usuario
3. Optimización de flujos de navegación del sistema

---

## Conclusión

Este documento proporciona el contexto necesario para interpretar correctamente los datos del sistema de llamadas y crear reportes significativos. La estructura identificada permite calcular promedios de interacciones por usuario con diferentes niveles de granularidad y calidad, según los requerimientos específicos del negocio.