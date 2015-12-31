extensions [web shell]

__includes ["red.nls" "tareas.nls"  "inicial.nls" ]

to idle
end

;por si seleccionan los separadores!!
to ACCIÓN-ACTUAL-------------
end

to go
  if reservar? = 0 [setup]
  if avanza-vehículos? [
      genera-vehículos
      ;avanza-vehículos
      ask vehículos [ obedecer ]
  ]
  let tamaño2 2.3 * tamaño-nodo
  every .6 [
    let ns nodos-seleccionados
    if ns != nobody [
      ask ns [ set size tamaño2 - size ]
    ]
    let ss semáforos-seleccionados
    if ss != nobody [
      ask ss [set size tamaño2 - size ]
    ]
  ]
  cambia-semáforos
  run (word "acción-actual-" acción-actual)
  tick
end

to genera-vehículos
  ask nodos with [es-origen?] [
    foreach sort my-out-calles [
      let cactual ?
      if random-float 1 < densidad and not any? vehículos-here [
        hatch-vehículos 1 [
          set size 1
          set calle-actual cactual
          set color one-of base-colors
          show-turtle
          set velocidad-deseada (0.5 + random-float 1)
          set arrivando-a-nodo? False
          set calle-siguiente nobody
          set metas [ ["camaleato-basico"] ["die"] ] ; una meta es una lista de tareas (aquí se plantean dos metas iniciales)
        ]  ; aunque "camaleato-basico" es una meta reemplazada por otras varias metas.
      ]
    ]
  ]
end


; Reemplaza metas
to-report reemplazar [s1 s2 s3] ; reemplaza las ocurrencias de s1 por s2 en s3
  while [member? s1 s3] [
    let pp position s1 s3
    set s3 replace-item pp s3 s2
  ]
  report s3
end

; crea carpeta
to crear-direc [direc]
  ifelse UNIX
  [ show (shell:exec "mkdir" "-p" direc) ]
  [ show (shell:exec "cmd" "/c" "mkdir" (reemplazar "/" "\\" direc)) ] 
end

; borra carpeta
to borrar-direc [direc]
  ifelse UNIX [ show (shell:exec "rm" "-rf" direc) ]
  [show (shell:exec "cmd" "/c" "rmdir" "/s/q" (reemplazar "/" "\\" direc))]
end

; crea carpeta temporal 
to crear-TEMP [am]
  if metainfo "archivo-modelo" = false [ agregar-metainfo "archivo-modelo" am ]
  agregar-metainfo "dir-temporal" (word TEMPD "/" (basename am))
  crear-direc metainfo "dir-temporal"
end

; borra carpeta temporal (no se borra si sucede un erro al cargar o borrar un modelo .tra)
to borrar-TEMP
  borrar-direc TEMPD
  borrar-metainfo "dir-temporal"
end
  
; reporta la carpeta temporal actual
to-report TEMP [arch]
  report (word metainfo "dir-temporal" "/" arch)
end

to abrir-modelo
  file-close-all
  if modelo-metainfo-lista = 0 or modelo-metainfo-lista = [] or user-yes-or-no? "Sus cambios al modelo actual se perderán, ¿continúo?" [
    let modelo-actual user-file
    if modelo-actual != false and file-exists? modelo-actual [
      setup
      borra-dirs-metainfo
      crear-TEMP modelo-actual
      show "Unzipping..."
      ifelse UNIX
      [ show (shell:exec "unzip" "-d" TEMP "" modelo-actual ) ]
      [ show (shell:exec "cmd" "/c" "7z" "e" "-y" "-tzip" (word "-o" TEMP "") modelo-actual ) ]
      abrir-fondo TEMP "fondo.png"
      abrir-red TEMP "red.txt"
      abrir-metainfo TEMP "metainfo.txt"
      borra-dirs-metainfo
      borrar-TEMP
      agregar-metainfo "archivo-modelo" modelo-actual
    ]
  ]
end

; extrae el nombre "base" de un modelo. Ej. /Mi/trayectoria/al/modelo123.tra -> "modelo123"
to-report basename [arch]
  if item 1 arch = ":" [set arch but-first but-first arch] ; elimina por ejemplo "C:" del inicio
  set arch reemplazar "\\" "/" arch ; traduce de paths de windows de ser necesario
  let l length arch
  let hcra reverse arch
  let sep 0
  let posd (position "/" hcra)
  show posd
  if posd = false [set posd l]
  let b l -  posd; ultima posicion de la diagonal
  let p position "." arch
  report substring arch b p
end 

; borra nombres de carpetas de la metainfo
to borra-dirs-metainfo
  borrar-metainfo "archivo-modelo"
  borrar-metainfo "dir-temporal"
end

; la metainfo contiene datos internos del modelo actual
to guardar-metainfo [arch]
  carefully [file-delete arch ][]
  let am modelo-metainfo-lista ; respalda metainfo
  borra-dirs-metainfo
  file-close-all
  file-open arch
  file-write modelo-metainfo-lista
  file-close-all
  set modelo-metainfo-lista am ; recupera metainfo respaldada
end

to abrir-metainfo [mi-archivo]
  file-close-all
  if file-exists? mi-archivo [
    file-open mi-archivo
    set modelo-metainfo-lista file-read 
    file-close-all
  ]
end

; agrega un dato a la metainfo (en la metainfo se guardan variables y valores útiles al modelo)
to agregar-metainfo [ mi-variable mi-valor ]
  borrar-metainfo mi-variable
  set modelo-metainfo-lista lput (list mi-variable mi-valor) modelo-metainfo-lista
end

to borrar-metainfo [mi-variable]
  let l []
  foreach modelo-metainfo-lista [
    if item 0 ? != mi-variable [set l lput ? l ]
  ]
  set modelo-metainfo-lista l
end

; obtiene el valor de mi-variable
to-report metainfo [mi-variable]
  foreach modelo-metainfo-lista [
    if item 0 ? = mi-variable [report item 1 ?]
  ]
  report false
end

; carga fondo desde coordenadas
to incorpora-coordenadas-fondo
  let direc remove " " user-input "Copia y pega aquí las coordenadas de Google maps. Ej. 19.3336169, -99.1514492"
  let base_dir1 "http://maps.googleapis.com/maps/api/staticmap?center="
  let base_dir2 "&zoom=18&size=429x429&maptype=satellite"
  agregar-metainfo "url-fondo" (word base_dir1 direc base_dir2)
  agregar-metainfo "lat,long" direc
  web:import-drawing metainfo "url-fondo"
  guardar-modelo
end

; si lo que se tiene es una url de donde jalar el fondo
to cargar-fondo-de-url
  let direc user-input "URL de archivo de fondo:"
  agregar-metainfo "url-fondo" direc
  borrar-fondo
  web:import-drawing direc
  guardar-modelo
end

to guardar-fondo [arch]
  file-close-all
  carefully [file-delete arch][]
  ask turtles [hide-turtle] ask links [hide-link]
  export-view arch
  ask turtles [show-turtle] ask links [show-link]
end

to abrir-fondo [arch]
  if arch != false [
    file-close-all
    show (word "abrir-fondo: " arch)
    borrar-fondo
    import-drawing arch
  ]
end

; utilitaria para guardar-red
to file-print-objetos-posicionales [mietiqueta miagentset]
  if any? miagentset [
    file-print (list (word "\"" mietiqueta "\"") map [[(list xcor ycor)] of ?] sort miagentset)
  ]
end

; la red incluye los elementos que se le dibujen encima al fondo, excepto los vehículos
to guardar-red [arch]
  if any? nodos [
    let lon sort nodos ;list ordenada de nodos
    let low map [ [who] of ? ] lon ; lista ordenada de who's
    ; - semaforos - 
    if arch != false [
      file-close-all
      carefully [ file-delete arch ] []
      file-open arch
      ; ["vecinos" [...lista de vecinos...]] 
      file-print (list "\"vecinos\"" map [[ [ position who low ] of out-calle-neighbors ] of ? ] lon)
      file-print (list "\"nodo.coordenadas\"" map [ [(list xcor ycor)] of ?] lon) ; ["nodo.coordenadas" [...lista de coord...]
      file-print (list "\"nodo.densidades\"" map [ [densidad] of ?] lon)
      file-print (list "\"nodo.colores\"" map [ [color] of ?] lon)
      file-print (list "\"nodo.tipos\"" map [ [tipo] of ?] lon)
      if any? semáforos [
        let los sort semáforos ;lista ordenada de semáforos
        file-print (list "\"semaforo.coordenadas\"" map [ [(list xcor ycor)] of ?] los)
        file-print (list "\"semaforo.calle-origen\"" map [ [[(list (position [who] of end1 low) (position [who] of end2 low))] of item 0 estados] of ?] los)
      ]
      file-print-objetos-posicionales "obstáculos.coordenadas" obstáculos
      file-print-objetos-posicionales "barreras.coordenadas" barreras
      file-close-all
    ]
  ]
end

to abrir-red [archivo]
  if archivo != false [
    file-open archivo
    let l 0
    let nodos-nuevos []
    let semáforos-nuevos-l []
    while [ not file-at-end? ] [
      set l file-read
      if is-list? l
      [
        let SECCION item 0 l
        let dato item 1 l
        if SECCION = "vecinos" [ foreach dato [ crea-nodo "pnodo" 0 0 set nodos-nuevos lput pnodo nodos-nuevos ]]
        if SECCION = "vecinos" [ let mwho [who] of (item 0 nodos-nuevos) (foreach nodos-nuevos dato [ask ?1 [foreach ?2 [my-create-calle-to nodo (? + mwho) ]]] )]
        if SECCION = "nodo.coordenadas" [ (foreach nodos-nuevos dato [ask ?1 [setxy (item 0 ?2) (item 1 ?2) ]] )]
        if SECCION = "nodo.densidades" [ (foreach nodos-nuevos dato [ask ?1 [set densidad ?2 ]] )]
        if SECCION = "nodo.colores" [ (foreach nodos-nuevos dato [ask ?1 [set color ?2 ]] )]
        if SECCION = "nodo.tipos" [ (foreach nodos-nuevos dato [ask ?1 [modifica-tipo-de-nodo ?2 ]] )]
        if SECCION = "semaforo.coordenadas" [ foreach dato [ crea-semáforo-aislado "pnodo" item 0 ? item 1 ? set semáforos-nuevos-l lput pnodo semáforos-nuevos-l]]
        if SECCION = "semaforo.calle-origen" [ (foreach semáforos-nuevos-l dato [ vincula-semáforo-a-calle ?1 (calle item 0 ?2 item 1 ?2) ] )]
        if SECCION = "obstáculos.coordenadas" [ foreach dato [ crea-obstáculo "pnodo" (item 0 ?) (item 1 ?) ]]
        if SECCION = "barreras.coordenadas" [ foreach dato [ crea-barrera "pnodo" (item 0 ?) (item 1 ?) ]]
      ]
    ]
    file-close-all
    set pnodo nobody
  ]
end

;guarda todo, llamado desde guardar-modelo
to guardar-archivos
  file-close-all
  crear-TEMP metainfo "archivo-modelo"
  guardar-fondo TEMP "fondo.png"
  guardar-red TEMP "red.txt"
  guardar-metainfo TEMP "metainfo.txt"
  let dt (metainfo "dir-temporal")
  show (word "dt: " dt)
  let am (metainfo "archivo-modelo")
  show (word "am: " am)
  ifelse UNIX [ 
    show (shell:exec "rm" "-f" am)
    show (shell:exec "zip" "-j" "-r" am dt)
  ]
  [ 
    show (shell:exec "cmd" "/c" "del" "/Q" am)
    show (shell:exec "cmd" "/c" "7z" "a" am "-tzip" (word ".\\" dt "\\*") ) 
  ]
  borrar-direc TEMPD
end

to guardar-modelo
  if modelo-metainfo-lista != 0 and modelo-metainfo-lista != [] [
    if metainfo "archivo-modelo" = false [ agregar-metainfo "archivo-modelo" "modelo-de-prueba.tra" ]
    guardar-archivos
    if mensajitos? [print (word "Modelo " (metainfo "archivo-modelo") " guardado")]
  ]
end

to guardar-modelo-como
    let modelo user-new-file
    if modelo != false [
      if position ".tra" modelo = false [set modelo (word modelo ".tra")]; si no se puso, ponerle la extensión .tra al archivo
      agregar-metainfo "archivo-modelo" modelo
      guardar-modelo
    ]
end

to borrar-fondo
  clear-drawing
end

; selecionador de acciones para el submenú fondo
to acción-con-fondo
  let mi-accion user-one-of "Fondo" ["abrir" "abrir con coordenadas" "abrir con URL" "guardar (jpg/png)" "borrar"]
  if mi-accion = "abrir" [ abrir-fondo user-file]
  if mi-accion = "abrir con coordenadas" [ incorpora-coordenadas-fondo ]
  if mi-accion = "abrir con URL" [ cargar-fondo-de-url ]
  if mi-accion = "guardar (jpg/png)" [ guardar-fondo user-new-file ]
  if mi-accion = "borrar" [ borrar-fondo ]
end

; seleccionador de acciones para el submenú red
to acción-con-red
  let mi-accion user-one-of "red" ["abrir" "incluir" "guardar" "borrar" "muestra/oculta"]
  if mi-accion = "abrir" [ borrar-red abrir-red user-file ]
  if mi-accion = "incluir" [ abrir-red user-file ]
  if mi-accion = "guardar" [ guardar-red user-new-file ]
  if mi-accion = "borrar" [ borrar-red ]
end

; seleccionador de acciones para el submenú seleccionar
to acción-con-seleccionar
  let mi-accion user-one-of "Selecciona..." 
  ["nada" "todo" "algunos nodos" "algunas aristas" "todos los nodos" "todas las aristas" "cambia nodos" "cambia aristas" "semáforos en nodo" "algunos semáforos"]
  if mi-accion = "todo" [ selección-selecciona-todo ]
  if mi-accion = "nada" [ selección-selecciona-nada ]
  if mi-accion = "algunos nodos" [ set acción-actual "selecciona-nodo" ]
  if mi-accion = "algunas aristas" [ set acción-actual "selecciona-arista" ]
  if mi-accion = "todos los nodos" [ selección-todos-los-nodos ]
  if mi-accion = "todas las aristas" [ selección-todas-las-aristas ]
  if mi-accion = "cambia nodos" [ selección-intercambia-nodos ]
  if mi-accion = "cambia aristas" [ selección-intercambia-aristas ]
  if mi-accion = "semáforos en nodo" [ set acción-actual "selec-semáforos-en-nodo" ]
  if mi-accion = "algunos semáforos" [ set acción-actual "selecciona-semáforo" ]
end

; que lástima que los parámetros de Netlogo no sean verdaderas listas
to-report attach [cadena valor]
  report (word cadena valor)
end

; acciones para modificar nodos seleccionados
to modifica-nodos-selec
  let ns nodos-seleccionados
  let c count ns
  user-message (word c " nodos seleccionados...") ; continua si hay nodos seleccionados
  if c > 0 [
    let colores remove-duplicates ([color] of ns)
    set colores ( word " (" colores ")" )
    
    let densidades remove-duplicates ([densidad] of ns)
    set densidades ( word " (" densidades ")" )
    
    let tipos remove-duplicates ([tipo] of ns)
    set tipos ( word " (" tipos ")" )
    
    let xcords remove-duplicates ([xcor] of ns)
    let ycords remove-duplicates ([ycor] of ns)
    let coordenadas 0
    ifelse length xcords > 1 or length ycords > 1 [set coordenadas "múltiples"]
    [set coordenadas (word (item 0 xcords) ", " (item 0 ycords))]
    set coordenadas ( word " (" coordenadas ")" )
      
    set colores attach "asigna a nodos el color de Paleta" colores
    set densidades attach "asigna a nodos la densidad de Paleta" densidades
    set tipos attach "tipos..." tipos
    set coordenadas attach "coordenadas..." coordenadas
    
    let mi-accion user-one-of "Modifica características de nodos..." (list colores densidades tipos coordenadas )
    if mi-accion = colores [ask ns [ set color paleta-color ]]
    if mi-accion = densidades [ask ns [ set densidad paleta-densidad ]]
    if mi-accion = tipos [
      let mis-tipos ["normal" "origen" "destino"]
      let t position (user-one-of "Escoge tipo de nodo..." mis-tipos) mis-tipos
      ask ns [ modifica-tipo-de-nodo t ] 
    ]
    if mi-accion = coordenadas [
      let msg (word "Teclea las coordenadas de pantalla.\n Ej." (item 0 xcords) ", " (item 0 ycords))
      let coord remove " " user-input msg
      set coord (word "[" (replace-item (position "," coord) coord " ") "]")
      set coord read-from-string coord
      ask ns [setxy item 0 coord item 1 coord]
    ]
  ]
end

; seleccionador de acciones para el submenú editar
to acción-con-editar
  let mi-accion user-one-of "Editar..." 
  ["nodos seleccionados" "detecta origenes/destinos" "sincroniza semáforos seleccionados"]
  if mi-accion = "nodos seleccionados" [ modifica-nodos-selec ]
  if mi-accion = "detecta origenes/destinos" [ detecta-origenes-destinos ]
  if mi-accion = "sincroniza semáforos seleccionados" [ sincroniza-semáforos ]
end

; seleccionador de acciones para el submenú ver
to acción-con-ver
  let mi-accion user-one-of "Ver..." 
  ["muestra/oculta red" "muestra/oculta semáforos" "nodos tamaño pequeño" "nodos tamaño mediano" "nodos tamaño grande" "metainfo"]
  if mi-accion = "muestra/oculta red" [ toggle-oculta-red-completa ]
  if mi-accion = "muestra/oculta semáforos" [ toggle-muestra-semáforos ]
  if mi-accion = "nodos tamaño pequeño" [ nodos-tamaño-pequeño ]
  if mi-accion = "nodos tamaño mediano" [ nodos-tamaño-mediano ]
  if mi-accion = "nodos tamaño grande" [ nodos-tamaño-grande ]
  if mi-accion = "metainfo" [ user-message modelo-metainfo-lista ]
end
@#$#@#$#@
GRAPHICS-WINDOW
225
10
664
470
16
16
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
0
10
66
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
5
298
102
331
Guardar como...
guardar-modelo-como
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
5
232
102
265
Abrir...
abrir-modelo
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
156
10
223
43
go
if mouse-inside? [go]
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
687
163
887
313
Vehículos en el crucero
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy ticks count vehículos\nif ticks > 800 [\n  set-plot-x-range ticks - 800 ticks\n]"

SLIDER
686
123
861
156
paleta-densidad
paleta-densidad
0
1
0.26
.01
1
NIL
HORIZONTAL

SWITCH
1
431
172
464
avanza-vehículos?
avanza-vehículos?
0
1
-1000

BUTTON
172
431
227
464
borra
ask vehículos [die]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
2
50
223
95
acción-actual
acción-actual
"añade-nodo" "borra-nodo" "mueve-nodo" "convierte-en-origen" "convierte-en-destino" "selecciona-nodo" "mueve-nodos-seleccionados" "añade-nodo-a-arista" "------------" "añade-arista" "borra-arista" "selecciona-arista" "invierte-sentido-de-calle" "------------" "añade-semáforo" "mueve-semáforo" "borra-semáforo" "selec-semáforos-en-nodo" "selecciona-semáforo" "------------" "añade-obstáculo" "mueve-obstáculo" "borra-obstáculo" "------------" "añade-barrera" "mueve-barrera" "borra-barrera"
9

CHOOSER
-1
95
224
140
selección
selección
"añade-aristas-entre-nodos" "haz-orígenes" "haz-destinos" "haz-nodos-normales" "construye-sistema-de-semáforos"
2

BUTTON
0
140
134
173
NIL
aplica-a-seleccionados
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
687
312
887
462
Velocidad promedio
NIL
NIL
0.0
10.0
0.0
1.5
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if any? vehículos [\n plotxy ticks mean [velocidad] of vehículos\n]\nif ticks > 800 [\n  set-plot-x-range ticks - 800 ticks\n]"

BUTTON
721
466
841
499
NIL
clear-all-plots
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
686
63
861
123
paleta-color
48
1
0
Color

TEXTBOX
35
219
76
237
Modelo
11
0.0
1

TEXTBOX
3
415
153
433
Vehículos
11
0.0
1

BUTTON
5
265
102
298
Guardar
guardar-modelo
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
5
331
102
364
Fondo...
acción-con-fondo
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
5
364
102
397
Red...
acción-con-red
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
120
219
197
237
Herramientas
11
0.0
1

BUTTON
114
232
194
265
Seleccionar...
acción-con-seleccionar
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
114
265
194
298
Editar...
acción-con-editar
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
114
298
194
331
Ver...
acción-con-ver
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
691
16
868
44
Paleta (para usar con Editar...)
11
0.0
1

BUTTON
686
30
861
63
NIL
paleta-defaults
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
# Gráficas-Tráfico (G-TRA)

## ¿Qué es?

Programa escrito en el lenguaje Netlogo (descargable de http://ccl.northwestern.edu/netlogo) para simular las condiciones de tráfico vehicular en cruceros y redes de estos, mediante un modelo basado en agentes computacionales.

El programa muestra el tráfico formado por vehículos simulados mediante caminates aleatorios sobre una red que se superpone al mapa de cruceros de la Ciudad de México.

IMPORTANTE: Para utilizar el simulador requerirás las extensiones "shell" y "web" (descárgalas de https://github.com/NetLogo/NetLogo/wiki/Extensions y copia las carpetas descomprimidas en la carpeta "extensions" del Netlogo instalado). Así mismo, en Windows requerirás el programa 7zip (7z.exe y 7z.dll aquí incluidos).

## ¿Cómo funciona?

Sobre un dibujo de fondo o mapa de una zona de la ciudad, trazas aristas indicando calles y nodos indicando intersecciones por los que transitarán vehículos desde los nodos orígenes hasta los nodos destinos, encontrándose en el camino con obstáculos, barreras, etc.

## ¿Cómo usarlo?

Para crear una nueva simulación, presiona SETUP y a continuación GO. Por default el programa permitirá agregar aristas y nodos sobre el área negra (World) y el tiempo (ticks) irá transcurriendo. Cuando esté dibujada al menos una arista, en "Herramientas"/"Editar" selecciona "detecta origenes/destinos" y presiona OK, algunos nodos cambiarán de forma automáticamente y si activas "avanza-vehículos?" se comenzarán a generar vehículos desde los orígenes y desaparecerán al llegar a algún destino, tomando aristas al azar al llegar a un nodo. Puedes agregar y borrar diversos objetos, además de modificar los existentes (como cambiar la posición de los nodos).

### Recuerda que el botón GO debe estar activo para poder realizar cambios interactivos como dibujar.

Adicionalmente puedes importar un dibujo como fondo de la simulación, en formato JPG o PNG, o copiar y pegar coordenadas desde Google Maps. Para esto último, localiza la zona que te interesa y dále click para que aparezca un señalizador. En el recuadro superior de información aparecerán las coordenadas correspondientes al centro del recuadro que aparecerá en el simulador.

Podrás guardar todo o abrir modelos completos previamente guardados (extensión ".tra") desde los menús de "Modelo" (Modelo/Abrir, etc.).

## Cosas para notar

Los nodos pueden moverse individualmente o en grupo (seleccionándolos), mediante la opción correspondiente, así como borrarse. Las aristas se pueden trazar entre nodos, cambiarles su sentido etc. Para crear una calle de doble sentido pueden trazarse dos aristas.

### Los vehículos no avanzarán si tienen un vehículo enfrente. Esto puede provocar congestionamientos al quedar bloqueados o simplemente puede provocar un avance más lento.

Nótese que la simulación se pone en pausa con el ratón fuera del área de dibujo.

## Cosas para probar

Utiliza otros mapas y créale sus propias calles, altera los sentidos de las calles, diseña puentes vehiculares (aristas de diferente color) y vé como aumenta o disminuye la velocidad promedio y número de vehículos en el crucero, etc.

Agrega "obstáculos" que hacen mas lenta la circulación de manera puntual, o "barreras" que impiden la circulación también de manera puntual. Los obstáculos pueden representar topes, zonas con vehículos mal estacionados, paraderos de transporte público, zonas escolares, de gasolineras o centros de verificación, etc. Las barreras son cierres (quizás temporales) de la circulación en ciertas aristas, a fin de observar las implicaciones en la circulación de vehículos en zonas circundantes.

Puedes cargar y guardar la red y el fondo de manera independiente. También "Modelo/Guardar como" es útil cuando quieres tener varias versiones de tu modelo, o hacerle cambios sin alterar versiones anteriores (de momento no está implementado "deshacer" un cambio, así que guarda tu modelo frecuentemenete).

Se tienen unas cuantas opciones para modificar la visualización (nodos mas pequeños, ocultar la red) desde Modelo/Ver.

De momento se pueden agregar semáforos, pero su operación es aún muy primitiva.

Por último, al modificar la "paleta" se pueden obtener efectos tanto visuales como de operación, ya que un vehículo transitando por una arista de un color no interferirá el movimiento de otro sobre una arista de otro color, con lo que se pueden simular puentes o pasos vehiculares. (superiores o inferiores, de tantos niveles como sean necesarios).

## Extendiendo el modelo

En futuras versiones se añadirán características que disminuyen o regulan el tráfico como semáforos, topes y puntos conflictivos (como escuelas, estaciones de servicio, paradas de transporte público, etc.). Se ha añadido semáforos al modelo, aunque la sincronización aún es manual, en futuras versiones se implementará una sincronización automática y una asistida.

Es importante notar que dadas las limitaciones de Netlogo, se utilizan los archivos "inicial.nls", "red.nls" y "tareas.nls" para dividir el código y es posible editarlas independientemente.

La forma en que avanzan los vehículos se basa aproximadamente en las "tareas" descritas en Netlogo aunque con algunas modificaciones. Cada vehículo obedece una lista de "metas" generada desde su creación. Para cumplir con una meta, el vehículo debe cubrir todas y cada una de las tareas de que consista dicha meta (la tarea es un reporteador que debe devolver True cuando esta esté cumplida). Un vehículo intentará todas las tareasd e una meta una y otra vez, en tanto haya al menos una no cumplida. Al cubrirlas todas, la meta queda obedecida y por tanto, eliminada de la lista de metas a realizar. La meta "die" debería ser la última en ser ejecutada e implica la eliminación del vehículo.

Carriles y cambios de carril es otra posible dirección de crecimiento.

Hay varias técnicas de programación incluidas en este programa que espero encuentres interesantes y elabores sobre ellas y disculpes las pobremente implementadas.

## Características de Netlogo

El programa usa de manera intensiva el ratón, y dado que Netlogo es muy pobre en este aspecto, el modelo resulta algo limitado. Aún así las diferentes formas de agregar, cambiar o borrar objetos con el ratón se trató de hacer lo mas intuitiva y parecida a los sistemas de dibujo tradicionales.

## Modelos Relacionados

Aquellos modelos vehiculares y de gráficas.

## Créditos y Referencias

(R) Noviembre de 2014. Felipe Humberto Contreras Alcalá, Oscar Valdés Ambrosio
Contacto: hobber.mallow+gtra@gmail.com

Este programa fué realizado como parte del proyecto de investigación PI2011-56R de la Universidad Autónoma de la Ciudad de México con apoyo y agradecimientos a la Secretaría del Ciencia, Tecnología e Innovación (SECITI) del Distrito Federal, México.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

car top
true
0
Polygon -7500403 true true 151 8 119 10 98 25 86 48 82 225 90 270 105 289 150 294 195 291 210 270 219 225 214 47 201 24 181 11
Polygon -16777216 true false 210 195 195 210 195 135 210 105
Polygon -16777216 true false 105 255 120 270 180 270 195 255 195 225 105 225
Polygon -16777216 true false 90 195 105 210 105 135 90 105
Polygon -1 true false 205 29 180 30 181 11
Line -7500403 false 210 165 195 165
Line -7500403 false 90 165 105 165
Polygon -16777216 true false 121 135 180 134 204 97 182 89 153 85 120 89 98 97
Line -16777216 false 210 90 195 30
Line -16777216 false 90 90 105 30
Polygon -1 true false 95 29 120 30 119 11

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

emblem2
false
0
Polygon -7500403 true true 0 90 15 120 285 120 300 90
Polygon -7500403 true true 30 135 45 165 255 165 270 135
Polygon -7500403 true true 60 180 75 210 225 210 240 180
Polygon -7500403 true true 150 285 15 45 285 45
Polygon -16777216 true false 75 75 150 210 225 75
Polygon -1184463 true false 75 75 225 75 150 210 75 75

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

dos carriles
0.0
-0.2 1 1.0 0.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

selec
0.0
-0.2 0 0.0 1.0
0.0 1 2.0 2.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

tres carriles
0.0
-0.2 1 1.0 0.0
0.0 1 1.0 0.0
0.2 1 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
