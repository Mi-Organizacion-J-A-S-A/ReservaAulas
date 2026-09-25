Fichero para configurar la base de datos remota. Se utiliza, tal como recomendó Gemini: Supabase.com que tiene un plan gratuito.


```sql
CREATE TABLE reservas (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  creado_en TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
  aula TEXT NOT NULL, -- 'Informática1', 'Informática2', 'Polos'
  fecha DATE NOT NULL,
  hora_inicio TIME NOT NULL,
  nombre_cliente TEXT NOT NULL,
  estado TEXT DEFAULT 'pendiente' -- 'pendiente', 'aceptada', 'denegada'
);

-- Activar Realtime para que la app reaccione al instante
alter publication supabase_realtime add table reservas;

```
