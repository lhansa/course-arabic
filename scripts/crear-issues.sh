#!/usr/bin/env bash
# Crea o actualiza los milestones, las labels y los issues del curso.
# Es idempotente: si algo ya existe (los issues se reconocen por su código, p. ej. "B1-03"), lo actualiza en vez de duplicarlo.
# Solo usa la API REST (gh api) porque en algunos entornos GraphQL está bloqueado.
#
# Uso: scripts/crear-issues.sh [owner/repo]   (por defecto lhansa/course-arabic)
set -euo pipefail

REPO="${1:-lhansa/course-arabic}"
API="repos/$REPO"

command -v gh >/dev/null || { echo "Falta gh (GitHub CLI)"; exit 1; }
command -v jq >/dev/null || { echo "Falta jq"; exit 1; }

# ---------------------------------------------------------------- labels
label() { # nombre color descripción
  local enc; enc=$(jq -rn --arg s "$1" '$s|@uri')
  if gh api "$API/labels/$enc" >/dev/null 2>&1; then
    gh api -X PATCH "$API/labels/$enc" -f color="$2" -f description="$3" >/dev/null
    echo "label  = $1"
  else
    gh api -X POST "$API/labels" -f name="$1" -f color="$2" -f description="$3" >/dev/null
    echo "label  + $1"
  fi
}

label "bloque-1"      "1d76db" "Bloque 1 — Sistema verbal"
label "bloque-2"      "0e8a16" "Bloque 2 — Estructuras nominales"
label "bloque-3"      "b60205" "Bloque 3 — Casos y modos"
label "bloque-4"      "5319e7" "Bloque 4 — Consolidación"
label "lección"       "fbca04" "Sesión con contenido nuevo (~15 min)"
label "repaso"        "c5def5" "Sesión de repaso, sin materia nueva"
label "por-desglosar" "d4c5f9" "Tema aún sin dividir en sesiones"

# ------------------------------------------------------------ milestones
MS=()  # indexado, compatible con bash 3.2 (macOS)
milestone() { # clave título descripción
  local num
  num=$(gh api "$API/milestones?state=all&per_page=100" \
        | jq -r --arg t "$2" '.[] | select(.title==$t) | .number' | head -n1)
  if [[ -n "$num" ]]; then
    gh api -X PATCH "$API/milestones/$num" -f description="$3" >/dev/null
    echo "mstone = $2 (#$num)"
  else
    num=$(gh api -X POST "$API/milestones" -f title="$2" -f description="$3" --jq .number)
    echo "mstone + $2 (#$num)"
  fi
  MS[$1]=$num
}

milestone 1 "Bloque 1 — Sistema verbal"        "Trimestre 1. Raíz y patrón, presente, pasado, futuro y negación. Vocabulario: rutina diaria, familia, casa."
milestone 2 "Bloque 2 — Estructuras nominales" "Trimestre 2. Idafa, números 1-10, dual, plurales, comparativo y superlativo. Vocabulario: comida, ciudad, compras."
milestone 3 "Bloque 3 — Casos y modos"         "Trimestre 3. Casos (إعراب), subjuntivo y yusivo, condicionales, voz pasiva. Vocabulario: trabajo, clima, viajes."
milestone 4 "Bloque 4 — Consolidación"         "Trimestre 4. Textos auténticos, redacciones guiadas, repaso de huecos, ampliación de vocabulario."

# ---------------------------------------------------------------- issues
EXISTING=$(gh api --paginate "$API/issues?state=all&per_page=100" \
           | jq -s '[.[][] | select(.pull_request|not) | {number, title}]')

issue() { # código título bloque labels(csv) cuerpo
  local code="$1" title="$1 · $2" ms="${MS[$3]}" labels="$4" body="$5" num
  num=$(jq -r --arg c "$code ·" '.[] | select(.title|startswith($c)) | .number' <<<"$EXISTING" | head -n1)
  local payload
  payload=$(jq -n --arg t "$title" --arg b "$body" --argjson m "$ms" --arg l "$labels" \
            '{title:$t, body:$b, milestone:$m, labels:($l|split(","))}')
  if [[ -n "$num" ]]; then
    gh api -X PATCH "$API/issues/$num" --input - <<<"$payload" >/dev/null
    echo "issue  = $title (#$num)"
  else
    num=$(gh api -X POST "$API/issues" --input - --jq .number <<<"$payload")
    echo "issue  + $title (#$num)"
  fi
}

body() { # objetivo prerrequisitos ejercicios vocabulario
  printf '**Objetivo**\n%s\n\n**Prerrequisitos**\n%s\n\n**Tipo de ejercicio**\n%s\n\n**Vocabulario**\n%s\n\n---\n_Plan de sesión, no lección. Protocolos en `CLAUDE.md`._\n' "$1" "$2" "$3" "$4"
}

pendiente() { # descripción
  printf '%s\n\n**Pendiente**: dividir en sesiones de ~15 min (una idea por sesión) antes de empezar, como en el Bloque 1. Ver `CLAUDE.md` §3.\n' "$1"
}

# ---- Bloque 1: sesiones reales -------------------------------------------
issue B1-01 "Raíz trilítera y patrón (وزن)" 1 "bloque-1,lección" "$(body \
"Entender que una palabra árabe = raíz (3 consonantes, el significado) + patrón (vocales y afijos, la función). Saber extraer la raíz de una palabra y reconocer el patrón base فَعَلَ." \
"Alifato. Nada más." \
"Opción múltiple: identificar la raíz de 6-8 palabras conocidas. Huecos: colocar las radicales de د-ر-س, ك-ت-ب y otra raíz en el molde فَعَلَ." \
"Rutina diaria: verbos básicos (دَرَسَ، كَتَبَ، شَرِبَ، أَكَلَ…).")"

issue B1-02 "Patrones nominales de una raíz: la familia de د-ر-س" 1 "bloque-1,lección" "$(body \
"Ver cómo los patrones generan familias de palabras previsibles: فاعِل (el que hace), مَفْعُول (lo hecho), مَفْعَلة (lugar), فِعالة / فَعْل (acción). Construir el mapa de د-ر-س que se usará todo el curso." \
"B1-01." \
"Huecos: generar la palabra a partir de raíz + patrón. Opción múltiple: deducir el significado de una palabra nueva por su patrón." \
"Casa y lugares (مَكْتَب، مَطْبَخ، مَدْرَسة…).")"

issue B1-03 "Presente I: el molde del مضارع y las personas del singular" 1 "bloque-1,lección" "$(body \
"Ver el presente como prefijo (persona) + base يَفْعُلُ + sufijo (número/género). Paradigma completo de أنا، أنتَ، أنتِ، هو، هي con دَرَسَ → يَدْرُسُ. Distinguir أنتَ / هي, que comparten تَـ." \
"B1-01. El presente es punto fuerte: sesión rápida para fijar el sistema, no para aprenderlo de cero." \
"Huecos: conjugar 3-4 verbos de rutina en las 5 personas. Opción múltiple: ¿quién es el sujeto de تَدْرُسُ? (ambigüedad أنتَ / هي)." \
"Rutina diaria: يَسْتَيْقِظُ، يَذْهَبُ، يَرْجِعُ، يَنامُ.")"

issue B1-04 "Presente II: el plural (نحن، أنتم، أنتنّ، هم، هنّ)" 1 "bloque-1,lección" "$(body \
"Completar el plural: نَـ para نحن, sufijo ـونَ para el masculino plural (أنتم / هم) y ـنَ para el femenino plural (أنتنّ / هنّ). Ver la simetría con el singular." \
"B1-03." \
"Huecos: conjugar en plural. Opción múltiple: elegir la forma según el sujeto. Redacción breve: 2 frases sobre la rutina de la familia." \
"Familia: أُسْرة، أَبٌ، أُمٌّ، أَخٌ، أُخْتٌ، أَوْلاد.")"

issue B1-05 "Presente III: el dual (أنتما، هما)" 1 "bloque-1,lección" "$(body \
"Introducir el dual verbal: sufijo ـانِ con تَـ (أنتما, هما femenino) y يَـ (هما masculino). Cerrar las 13 personas. Primer contacto con el dual, que es punto débil; se ampliará en B2." \
"B1-03, B1-04." \
"Opción múltiple: singular / dual / plural de una misma forma. Huecos: conjugar con sujetos dobles (الأَخَوانِ، البِنْتانِ)." \
"Familia: الوالِدانِ، التَّوْأَمانِ, hermanos.")"

issue B1-06 "Repaso: el presente completo (13 personas)" 1 "bloque-1,repaso" "$(body \
"Reproducir la tabla completa del presente de memoria a partir de su lógica, y aplicarla con verbos nuevos de patrón regular." \
"B1-03, B1-04, B1-05." \
"Huecos: tabla de يَدْرُسُ por completar. Opción múltiple con distractores entre dual y plural. Redacción breve: un día normal (3 frases)." \
"Rutina diaria y familia (repaso).")"

issue B1-07 "Pasado I: el molde del ماضي y las personas del singular" 1 "bloque-1,lección" "$(body \
"Ver el pasado como sistema de sufijos (frente a los prefijos del presente): دَرَسَ، دَرَسَتْ، دَرَسْتَ، دَرَسْتِ، دَرَسْتُ. Fijarse en la tā’ de cada persona." \
"B1-01. El pasado está oxidado: reactivarlo desde el sistema." \
"Huecos: conjugar verbos de rutina en las personas del singular. Opción múltiple: distinguir دَرَسْتَ / دَرَسْتِ / دَرَسْتُ / دَرَسَتْ (con tashkil)." \
"Rutina diaria: ayer (أَمْسِ، صَباحًا، مَساءً).")"

issue B1-08 "Pasado II: plural y dual" 1 "bloque-1,lección" "$(body \
"Completar las 13 personas del pasado: ـنا، ـتُمْ، ـتُنَّ، ـوا (con alif ortográfica)، ـنَ، ـتُما، ـا، ـتا." \
"B1-07, B1-05." \
"Huecos: tabla de دَرَسَ por completar. Opción múltiple: identificar el sujeto por el sufijo." \
"Familia: lo que hizo cada uno el fin de semana.")"

issue B1-09 "Pasado y presente: dos ejes del mismo verbo" 1 "bloque-1,lección" "$(body \
"Pasar con soltura de una forma a otra en la misma persona (دَرَسْنا ↔ نَدْرُسُ). Ver que el presente marca la persona sobre todo delante y el pasado detrás." \
"B1-06, B1-08." \
"Huecos: transformar frases del presente al pasado y al revés. Opción múltiple: elegir el tiempo según el marcador temporal (أَمْسِ / كُلَّ يَوْمٍ / الآنَ)." \
"Casa: tareas domésticas (طَبَخَ، نَظَّفَ، غَسَلَ).")"

issue B1-10 "Repaso: pasado (13 personas) y contraste con el presente" 1 "bloque-1,repaso" "$(body \
"Consolidar el pasado, que era punto oxidado, y medir si ya es tan seguro como el presente." \
"B1-07, B1-08, B1-09." \
"Huecos con mezcla de tiempos. Redacción breve: qué hizo ayer la familia (3-4 frases)." \
"Rutina, familia y casa (repaso).")"

issue B1-11 "Futuro: سـ / سوف" 1 "bloque-1,lección" "$(body \
"Ver el futuro como presente + partícula: سَـ (pegada, futuro cercano) y سَوْفَ (separada, más lejano o enfático). No hay conjugación nueva." \
"B1-06." \
"Huecos: pasar frases al futuro. Opción múltiple: سـ o سوف según el contexto. Redacción breve: planes para mañana (2-3 frases)." \
"Rutina: غَدًا، بَعْدَ غَدٍ، الأُسْبوع القادِم.")"

issue B1-12 "Negación I: لا + presente y ليس en la frase nominal" 1 "bloque-1,lección" "$(body \
"Repartir el trabajo: لا niega el verbo en presente y ليس niega la frase nominal (y se conjuga como un pasado). Repasar las formas de ليس con su lógica." \
"B1-06, B1-08." \
"Opción múltiple: لا o ليس según la frase. Huecos: negar frases nominales y verbales." \
"Casa: descripciones (البَيْتُ لَيْسَ كَبيرًا…).")"

issue B1-13 "Negación II: لم + yusivo (introducción ligera)" 1 "bloque-1,lección" "$(body \
"لم niega el pasado pero usa el presente en yusivo (لَمْ يَدْرُسْ). Introducción ligera: sukún final y caída de la ن en ـونَ / ـانِ / ـينَ. Solo verbos regulares; el modo completo se ve en el Bloque 3." \
"B1-10, B1-12." \
"Huecos: negar frases en pasado con لم. Opción múltiple: elegir entre ما دَرَسَ / لَمْ يَدْرُسْ / لَمْ يَدْرُسُ (la última es un distractor)." \
"Rutina: lo que no hice ayer.")"

issue B1-14 "Negación III: لن + subjuntivo y el cuadro completo" 1 "bloque-1,lección" "$(body \
"لن niega el futuro con el presente en subjuntivo (لَنْ يَدْرُسَ): fatha final y caída de la ن, sin سـ. Cerrar el cuadro: لا (presente), لم (pasado), لن (futuro), ليس (frase nominal), y mencionar ما + pasado." \
"B1-11, B1-13." \
"Opción múltiple: elegir la negación según el tiempo. Huecos: negar la misma frase en los tres tiempos." \
"Familia: planes y promesas.")"

issue B1-15 "Repaso: la negación como sistema" 1 "bloque-1,repaso" "$(body \
"Aplicar sin dudar la negación correcta en cualquier tiempo y con cualquier tipo de frase." \
"B1-12, B1-13, B1-14." \
"Huecos mixtos. Corregir errores de frases mal negadas. Redacción breve: lo que no hay en mi casa / lo que no haré (3 frases)." \
"Casa (repaso).")"

issue B1-16 "Repaso final del Bloque 1: el verbo en contexto" 1 "bloque-1,repaso" "$(body \
"Comprobar el bloque entero en un texto corto: tiempo, persona, negación y raíz/patrón. Detectar huecos antes de pasar al Bloque 2." \
"B1-01 a B1-15." \
"Leer un texto breve sin tashkil sobre una familia y responder preguntas (opción múltiple). Redacción breve guiada: mi semana (pasado, presente, futuro y alguna negación)." \
"Rutina diaria, familia y casa.")"

# ---- Bloques 2-4: un issue por tema, por desglosar ----------------------
issue B2-01 "Idafa (إضافة)" 2 "bloque-2,por-desglosar" "$(pendiente "Estructura de la idafa: el primer término sin artículo ni tanwín, la determinación por el segundo, las cadenas de idafa y la posición del adjetivo.")"
issue B2-02 "Números 1-10 y concordancia inversa" 2 "bloque-2,por-desglosar" "$(pendiente "La regla completa: 1-2 concuerdan; 3-10 llevan el género invertido respecto al singular del contado, que va en plural genitivo. **Punto débil del alumno**: hay que darle sesiones de más.")"
issue B2-03 "Dual (مثنى) en nombres y verbos" 2 "bloque-2,por-desglosar" "$(pendiente "Dual nominal (ـانِ / ـَيْنِ), concordancia con adjetivos y demostrativos (هذانِ / هاتانِ), caída de la ن en idafa, y enlace con el dual verbal de B1-05. **Punto débil del alumno**.")"
issue B2-04 "Plurales sanos y rotos (patrones frecuentes)" 2 "bloque-2,por-desglosar" "$(pendiente "Plurales sanos masculino y femenino, y los patrones rotos más frecuentes (أَفْعال، فُعُول، فُعَلاء، مَفاعِل، فِعال…). Concordancia de plurales no humanos en femenino singular. **Punto débil del alumno**.")"
issue B2-05 "Comparativo y superlativo (أفعل التفضيل)" 2 "bloque-2,por-desglosar" "$(pendiente "El patrón أَفْعَل: comparativo con مِنْ, superlativo con idafa o artículo, y formas con أَكْثَر / أَشَدّ + masdar.")"
issue B2-06 "Vocabulario: comida, ciudad, compras" 2 "bloque-2,por-desglosar" "$(pendiente "Campos léxicos del bloque. Se reparten entre las sesiones de los temas anteriores; este issue sirve para controlar la cobertura y para alguna sesión específica.")"

issue B3-01 "Casos (إعراب): مرفوع / منصوب / مجرور" 3 "bloque-3,por-desglosar" "$(pendiente "La lógica completa de los casos: qué función marca cada uno, desinencias con y sin tanwín, y diptotos. Aplicación a la frase nominal y a la verbal.")"
issue B3-02 "Subjuntivo (منصوب) y yusivo (مجزوم) del verbo" 3 "bloque-3,por-desglosar" "$(pendiente "Los modos del مضارع como sistema: partículas que rigen subjuntivo (أَنْ، لَنْ، لِـ، كَيْ…) y yusivo (لَمْ، لا prohibitivo، لِـ imperativo). Amplía lo introducido en B1-13 y B1-14. Relación con el imperativo.")"
issue B3-03 "Condicionales (إذا / لو / إن)" 3 "bloque-3,por-desglosar" "$(pendiente "Real, posible e irreal: tiempos y modos de la prótasis y la apódosis, y uso de فـ.")"
issue B3-04 "Voz pasiva (المبني للمجهول)" 3 "bloque-3,por-desglosar" "$(pendiente "La pasiva interna: patrón فُعِلَ / يُفْعَلُ, cuándo se usa y alternativas frecuentes en la prensa (تَمَّ + masdar).")"
issue B3-05 "Vocabulario: trabajo, clima, viajes" 3 "bloque-3,por-desglosar" "$(pendiente "Campos léxicos del bloque, repartidos entre las sesiones de los temas.")"

issue B4-01 "Textos auténticos sencillos (con y sin tashkil)" 4 "bloque-4,por-desglosar" "$(pendiente "Lectura analítica de textos reales cortos (avisos, noticias breves, textos divulgativos). Paso progresivo de texto con tashkil a texto sin tashkil.")"
issue B4-02 "Redacciones breves guiadas" 4 "bloque-4,por-desglosar" "$(pendiente "Redacciones de 4-8 frases con consignas gramaticales concretas (usar un dual, un número, una negación con لن…).")"
issue B4-03 "Repaso de bloques anteriores, detectando huecos" 4 "bloque-4,repaso,por-desglosar" "$(pendiente "Diagnóstico a partir de los puntos flojos de \`progreso.md\` y sesiones de repaso dirigidas a esos huecos.")"
issue B4-04 "Ampliación de vocabulario" 4 "bloque-4,por-desglosar" "$(pendiente "Ampliación por raíces y patrones (aprovechando B1-02), con temas cotidianos.")"

echo "Listo."
