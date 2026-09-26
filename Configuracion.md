# Gestión de Aulas - Guía de Configuración y Despliegue

Esta aplicación está desarrollada en **Flutter** y utiliza **Supabase** como backend, con una arquitectura desacoplada mediante un repositorio que permite cambiar fácilmente de proveedor de base de datos en el futuro.

Para desplegar y configurar este proyecto en una nueva institución, sigue los pasos detallados a continuación.

---

## 1. Configuración de la Base de Datos (Supabase)

1. Crea una cuenta e inicia sesión en [Supabase](https://supabase.com).
2. Crea un **New Project** (Nuevo Proyecto) con una contraseña segura para la base de datos.
3. Ve a la sección **SQL Editor** en el panel izquierdo de Supabase, crea una nueva consulta y ejecuta el siguiente script para crear las tablas necesarias e inicializar las políticas de seguridad:

```sql
-- Tabla para almacenar los días bloqueados (festivos, cierres, etc.)
CREATE TABLE IF NOT EXISTS dias_bloqueados (
    fecha DATE PRIMARY KEY
);

-- Tabla para almacenar las reservas de las aulas
CREATE TABLE IF NOT EXISTS reservas (
    id SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    aula TEXT NOT NULL,
    hora_inicio TIME NOT NULL,
    nombre_cliente TEXT NOT NULL,
    estado TEXT DEFAULT 'pendiente', -- 'pendiente', 'aceptada', 'denegada'
    uso TEXT DEFAULT 'Clase'
);

-- Habilitar RLS (Row Level Security) en las tablas
ALTER TABLE dias_bloqueados ENABLE ROW LEVEL SECURITY;
ALTER TABLE reservas ENABLE ROW LEVEL SECURITY;

-- Políticas de acceso público para lectura y escritura en reservas
CREATE POLICY "Permitir lectura de reservas a todos" ON reservas FOR SELECT USING (true);
CREATE POLICY "Permitir insercion de reservas a todos" ON reservas FOR INSERT WITH CHECK (true);
CREATE POLICY "Permitir actualizar reservas a todos" ON reservas FOR UPDATE USING (true);
CREATE POLICY "Permitir borrar reservas a todos" ON reservas FOR DELETE USING (true);

-- Políticas de acceso para días bloqueados
CREATE POLICY "Permitir lectura de dias bloqueados a todos" ON dias_bloqueados FOR SELECT USING (true);
```

4. Ve a **Authentication -> Providers -> Email** y asegúrate de que esté habilitado.
5. Ve a **Authentication -> Users** y añade un usuario técnico (correo y contraseña) que servirá para que el perfil de técnico inicie sesión en la aplicación.

---

## 2. Configuración del Entorno de la App

1. En la raíz de tu proyecto Flutter, busca el archivo `.env.example` (o créalo si no existe).
2. Duplícalo y nombra la copia simplemente como `.env`.
3. Rellena las variables con los datos de tu proyecto de Supabase (los encontrarás en **Project Settings -> API**):

```text
SUPABASE_URL=https://tu-proyecto-id.supabase.co
SUPABASE_ANON_KEY=tu-anon-key-publica-aqui
```

---

## 3. Instalación y Ejecución

Una vez configurado Supabase y el archivo `.env`, abre tu terminal en la carpeta raíz del proyecto y ejecuta los siguientes comandos:

1. **Obtener las dependencias del proyecto:**
   ```bash
   flutter pub get
   ```

2. **Ejecutar la aplicación (en tu emulador o dispositivo físico):**
   ```bash
   flutter run
   ```

---

## 4. Estructura de Ficheros Clave

* `main.dart`: Punto de entrada, inicialización de dependencias y pantallas de autenticación por rol.
* `database_repository.dart`: Contrato y capa de abstracción de datos. Contiene la implementación de Supabase actual. Si en el futuro deseas cambiar a otra base de datos (como Firebase o una API REST en Laravel), solo debes implementar esta interfaz sin modificar las pantallas.
* `profesor_screen.dart`: Interfaz y lógica para la consulta de calendarios, selección de tramos e inserción de solicitudes por parte de los profesores.
* `tecnico_screen.dart`: Panel de control en tiempo real para el técnico, permitiendo aprobar, denegar peticiones y visualizar el estado global de las aulas.