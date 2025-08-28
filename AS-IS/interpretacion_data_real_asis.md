# 🔍 **AS-IS: Interpretación de Data Real - Hallazgos Iniciales**

## 📊 **Análisis de la Muestra de Datos**

### **Campos y Estructura Identificados:**
```
idRe, numero_entrada, numero_digitado, menu, opcion, id_CTransferencia, fecha, 
division, area, hora_inicio, hora_fin, id_8T, etiquetas, cIdentifica, fecha_inserta, nidMQ
```

---

## 🧠 **Interpretación de Patrones Encontrados**

### **1. Relación numero_entrada vs numero_digitado**

#### **Patrones Identificados:**
- **Iguales**: `2185424078 = 2185424078` → Comportamiento "directo"
- **Diferentes**: `2185488041 → 2255709973` → ¿Transferencia/Enrutamiento?
- **Vacío en numero_digitado**: Algunos registros no tienen valor

#### **Ejemplos de Comportamiento:**
```
IGUALES: 2185424078 → 2185424078 [menu: SDO]
DIFERENTES: 2185488041 → 2255709973 [menu: RES-ContratacionIfm_2024]
VACÍO: 2185530869 → [vacío] [menu: SinOpcion_Cbc]
```

### **2. Campo 'etiquetas' - CLAVE PARA VALIDEZ**

#### **Valores Encontrados:**
- `2L,ZMB,VSI,NVS,` → Códigos de sistemas/procesos
- `1L,ZMB,DG,WTS,VSI,` → Configuraciones técnicas
- `NoTmx_SOMC,NoTmx_SOMC,` → Estados de error/excepción
- Vacío → Sin metadatos

#### **Interpretación Inicial:**
- **ZMB** = Aparece frecuentemente (¿zona/sistema base?)
- **VSI** = Común en muchos registros (¿validación?)
- **NOBOT** = ¿Indica interacción humana vs automatizada?
- **WTS** = ¿Sistema específico?

### **3. Patrones de Menús y Opciones**

#### **Tipos de Menú Identificados:**
```
OPERACIONES:
- SDO (Saldo)
- RES-ContratacionIfm_2024 (Contratación)
- RES_FALLA_STOP (Fallas)
- Desborde_Cabecera (Sobrecarga)

ESTADOS/ERRORES:
- SinOpcion_Cbc (Sin opción)
- cte_colgo (Cliente colgó)
- Numero tel (Número telefónico)
- NOTMX-SgmInsta (No México segmento)

ESPECIALIZADOS:
- comercial_5, comercial_11
- PG_TC (¿Pago tarjeta crédito?)
- GDL_V (Guadalajara específico)
```

### **4. Timestamps - Problema Real Identificado**

#### **Ejemplo de Inversión:**
```
ID: 382772952
hora_inicio: 01/01/1900 09:29:23
hora_fin:    01/01/1900 09:25:50
→ fin < inicio = INVERTIDO
```

#### **Patrón de Fechas Extraño:**
- Todas las horas usan fecha `01/01/1900` 
- La fecha real está en campo `fecha`
- **Interpretación**: `hora_inicio/hora_fin` solo almacenan tiempo, no fecha completa

---

## 📈 **Análisis de Comportamiento por Usuario**

### **Ejemplo: numero_entrada = 2185530869**
```
09:35:52 → SinOpcion_Cbc (Sin opción)
09:38:01 → cte_colgo (Cliente colgó)  
09:40:40 → cte_colgo (Cliente colgó)
09:38:22 → Desborde_Cabecera (Sobrecarga)
```
**Interpretación**: Usuario con múltiples intentos fallidos

### **Ejemplo: numero_entrada = 2169010041**
```
12:33:12 → Desborde_Cabecera, TELCO
12:45:31 → RES-SP_2024 → numero_digitado: 2694810004
12:35:17 → RES-SP_2024 → numero_digitado: 2694859708  
12:28:48 → Desborde_Cabecera, TELCO → numero_digitado: 9899438399
```
**Interpretación**: Usuario navegando por múltiples servicios/destinos

---

## 🎯 **Análisis AS-IS: Patrones de numero_entrada**

### **1. Análisis de Journey por Usuario (Patrón Principal Solicitado)**
```sql
-- CONCEPTO: Reconstruir el viaje completo de cada numero_entrada
SELECT 
    numero_entrada,
    fecha,
    COUNT(*) as total_interacciones,
    
    -- Journey temporal reconstruido
    GROUP_CONCAT(
        CONCAT(
            TIME_FORMAT(
                CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END, 
                '%H:%i'
            ), 
            ':[', COALESCE(menu, 'SIN_MENU'), '-', COALESCE(opcion, 'SIN_OPCION'), ']'
        ) 
        ORDER BY CASE WHEN hora_fin < hora_inicio THEN hora_fin ELSE hora_inicio END
        SEPARATOR ' → '
    ) as patron_navegacion,
    
    -- Análisis de destinos
    GROUP_CONCAT(DISTINCT numero_digitado SEPARATOR ',') as numeros_destino,
    COUNT(DISTINCT numero_digitado) as destinos_diferentes,
    
    -- Análisis de etiquetas
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_sesion
    
FROM llamadas_Q1  -- Repetir para Q2, Q3
WHERE numero_entrada IS NOT NULL
GROUP BY numero_entrada, fecha
ORDER BY numero_entrada, fecha;
```

### **2. Análisis de Validez por Campo 'etiquetas'**
```sql
-- CONCEPTO: ¿Las etiquetas indican tipos de interacción válidos?
SELECT 
    CASE 
        WHEN etiquetas LIKE '%VSI%' THEN 'CON_VSI'
        WHEN etiquetas LIKE '%NOBOT%' THEN 'INTERACCION_HUMANA'
        WHEN etiquetas LIKE '%ZMB%' THEN 'ZONA_BASE'
        WHEN etiquetas IS NULL OR etiquetas = '' THEN 'SIN_ETIQUETAS'
        ELSE 'OTROS'
    END as tipo_por_etiqueta,
    
    COUNT(*) as total_registros,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- ¿Los tipos tienen patrones de relación numero_entrada/numero_digitado?
    SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) as numeros_iguales,
    SUM(CASE WHEN numero_entrada != numero_digitado THEN 1 ELSE 0 END) as numeros_diferentes,
    SUM(CASE WHEN numero_digitado IS NULL THEN 1 ELSE 0 END) as sin_numero_digitado,
    
    -- Menús más frecuentes por tipo
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 5) as menus_frecuentes
    
FROM llamadas_Q1
GROUP BY tipo_por_etiqueta
ORDER BY total_registros DESC;
```

### **3. Análisis de Patrones de Menu/Opcion**
```sql
-- CONCEPTO: ¿Qué revelan los menús sobre el comportamiento?
SELECT 
    menu,
    opcion,
    COUNT(*) as frecuencia_uso,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    
    -- ¿Estos menús tienden a tener numero_entrada = numero_digitado?
    ROUND(SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_numeros_iguales,
    
    -- Duración promedio (corrigiendo timestamps invertidos)
    ROUND(AVG(
        CASE 
            WHEN hora_fin < hora_inicio THEN TIME_TO_SEC(hora_inicio) - TIME_TO_SEC(hora_fin)
            ELSE TIME_TO_SEC(hora_fin) - TIME_TO_SEC(hora_inicio)
        END
    ), 2) as duracion_promedio_seg,
    
    -- Distribución geográfica
    COUNT(DISTINCT id_8T) as zonas_geograficas,
    GROUP_CONCAT(DISTINCT division ORDER BY division LIMIT 3) as divisiones_principales
    
FROM llamadas_Q1
WHERE menu IS NOT NULL
GROUP BY menu, opcion
ORDER BY frecuencia_uso DESC
LIMIT 20;
```

### **4. Análisis de Transferencias/Enrutamiento**
```sql
-- CONCEPTO: ¿Qué pasa cuando numero_entrada ≠ numero_digitado?
SELECT 
    numero_entrada,
    numero_digitado,
    COUNT(*) as frecuencia_combinacion,
    
    -- ¿Qué menus/opciones usan estas combinaciones?
    GROUP_CONCAT(DISTINCT CONCAT(menu, ':', opcion) SEPARATOR ', ') as menu_opciones_usadas,
    
    -- ¿Hay patrones en las etiquetas?
    GROUP_CONCAT(DISTINCT etiquetas SEPARATOR '|') as etiquetas_patron,
    
    -- ¿En qué zonas sucede?
    GROUP_CONCAT(DISTINCT id_8T SEPARATOR ',') as zonas_afectadas,
    
    -- ¿Qué divisiones/áreas?
    GROUP_CONCAT(DISTINCT CONCAT(division, '-', area) SEPARATOR ', ') as divisiones_areas,
    
    -- Análisis temporal
    COUNT(DISTINCT fecha) as dias_activos,
    MIN(fecha) as primera_aparicion,
    MAX(fecha) as ultima_aparicion
    
FROM llamadas_Q1
WHERE numero_entrada != numero_digitado 
  AND numero_digitado IS NOT NULL
GROUP BY numero_entrada, numero_digitado
ORDER BY frecuencia_combinacion DESC
LIMIT 15;
```

### **5. Análisis de Anomalías y Calidad**
```sql
-- CONCEPTO: Detectar patrones anómalos sin corregir aún
SELECT 
    'TIMESTAMPS_INVERTIDOS' as tipo_anomalia,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 3) as menus_frecuentes,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje_total
FROM llamadas_Q1 
WHERE hora_fin < hora_inicio

UNION ALL

SELECT 
    'SIN_MENU_NI_OPCION' as tipo_anomalia,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    'N/A' as menus_frecuentes,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje_total
FROM llamadas_Q1 
WHERE menu IS NULL AND opcion IS NULL

UNION ALL

SELECT 
    'SIN_NUMERO_DIGITADO' as tipo_anomalia,
    COUNT(*) as casos,
    COUNT(DISTINCT numero_entrada) as usuarios_afectados,
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 3) as menus_frecuentes,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM llamadas_Q1), 2) as porcentaje_total
FROM llamadas_Q1 
WHERE numero_digitado IS NULL OR numero_digitado = '';
```

### **6. Análisis Geográfico y Organizacional**
```sql
-- CONCEPTO: ¿Hay diferencias por zona/división?
SELECT 
    id_8T as zona_geografica,
    division,
    area,
    COUNT(*) as total_interacciones,
    COUNT(DISTINCT numero_entrada) as usuarios_unicos,
    COUNT(DISTINCT fecha) as dias_activos,
    
    -- Promedio de interacciones por usuario por día
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT numero_entrada) / COUNT(DISTINCT fecha), 2) as promedio_interacciones_usuario_dia,
    
    -- Distribución de relación números
    ROUND(SUM(CASE WHEN numero_entrada = numero_digitado THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_numeros_iguales,
    
    -- Menús más frecuentes por zona/división
    GROUP_CONCAT(DISTINCT menu ORDER BY menu LIMIT 3) as menus_principales,
    
    -- ¿Problemas de timestamps por zona?
    ROUND(SUM(CASE WHEN hora_fin < hora_inicio THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_timestamps_invertidos
    
FROM llamadas_Q1
WHERE id_8T IS NOT NULL
GROUP BY id_8T, division, area
ORDER BY total_interacciones DESC;
```

---

## 🔍 **Hipótesis AS-IS para Validar**

### **Hipótesis 1: Campo 'etiquetas' Define Validez**
- **Teoría**: Las etiquetas con `VSI`, `ZMB`, etc. indican interacciones válidas/procesadas
- **Validación**: Comparar comportamiento entre registros con/sin ciertas etiquetas

### **Hipótesis 2: numero_digitado es Destino de Transferencia**
- **Teoría**: Cuando `numero_entrada ≠ numero_digitado`, el segundo es hacia dónde se enruta
- **Validación**: Ver si `numero_digitado` aparece como `numero_entrada` en otros registros

### **Hipótesis 3: Menús Revelan Tipo de Interacción**
- **Teoría**: `cte_colgo`, `SinOpcion_Cbc` = fallidas; `RES-*`, `comercial_*` = exitosas
- **Validación**: Analizar patrones de duración y etiquetas por tipo de menú

### **Hipótesis 4: Timestamps Invertidos Siguen Patrón**
- **Teoría**: Los timestamps invertidos no son aleatorios, siguen patrón de sistema/horario
- **Validación**: Analizar distribución temporal y por zona de timestamps invertidos

---

## 🎯 **Próximos Pasos AS-IS Recomendados**

### **1. Ejecutar Análisis de Validación (Inmediato)**
1. **Query 2** → Entender campo `etiquetas`
2. **Query 4** → Investigar transferencias `numero_entrada ≠ numero_digitado`
3. **Query 3** → Patrones de menús más frecuentes

### **2. Validar Hipótesis (Esta Semana)**
1. **¿Las etiquetas definen validez?** → Comparar comportamiento
2. **¿numero_digitado es destino?** → Rastrear números entre registros
3. **¿Los menús indican éxito/fallo?** → Analizar duraciones y contexto

### **3. Definir Estrategia de Reporte (Próxima Semana)**
Basado en los hallazgos:
- **¿Incluir solo ciertos tipos de etiquetas en promedio?**
- **¿Contar transferencias como interacciones separadas?**
- **¿Filtrar por menús exitosos vs fallidos?**

---

## 📊 **Entregables AS-IS Esperados**

### **Reporte de Interpretación**
1. **Significado real** de cada campo clave
2. **Definición de interacción válida** basada en patrones encontrados
3. **Clasificación de tipos** de usuario/comportamiento

### **Análisis de Comportamiento**
1. **Journeys típicos** por tipo de usuario
2. **Patrones de transferencia** y enrutamiento
3. **Identificación de usuarios anómalos** (posibles internos/testing)

### **Recomendaciones para Reporte Final**
1. **Filtros recomendados** para el cálculo de promedio
2. **Definición final** de "interacción válida"
3. **Estrategia de limpieza** específica para problemas identificados

---

**🔍 ¿Empezamos ejecutando estos queries para validar las hipótesis y entender el comportamiento real del sistema?**