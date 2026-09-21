from flask import Flask, request, jsonify
from flask_cors import CORS

import yt_dlp
import os
import threading
import subprocess
import sys
import re
import sqlite3
import time
import ctypes
import socket


# ============================================================
# CONFIGURACIÓN
# ============================================================

app = Flask(__name__)

CORS(
    app,
    resources={
        r"/*": {
            "origins": "*"
        }
    }
)

HOST = "0.0.0.0"
PORT = 8765


BASE_DIR = os.path.dirname(
    os.path.abspath(__file__)
)


CARPETA_DESCARGAS = os.path.join(
    BASE_DIR,
    "musica"
)


CARPETA_VIDEOS = os.path.join(
    BASE_DIR,
    "videos"
)


BASE_DATOS = os.path.join(
    BASE_DIR,
    "playlist.db"
)


os.makedirs(
    CARPETA_DESCARGAS,
    exist_ok=True
)


os.makedirs(
    CARPETA_VIDEOS,
    exist_ok=True
)


# ============================================================
# CABECERAS LAN / PRIVATE NETWORK ACCESS
# ============================================================

@app.after_request
def cabeceras_lan(response):

    response.headers[
        "Access-Control-Allow-Private-Network"
    ] = "true"

    response.headers[
        "Access-Control-Allow-Origin"
    ] = "*"

    response.headers[
        "Access-Control-Allow-Headers"
    ] = "*"

    response.headers[
        "Access-Control-Allow-Methods"
    ] = "GET,POST,OPTIONS"

    return response


# ============================================================
# BLOQUEOS
# ============================================================

descarga_lock = threading.Lock()

reproduccion_lock = threading.Lock()

estado_lock = threading.Lock()


# ============================================================
# ESTADO
# ============================================================

reproduciendo = False

video_actual = ""

titulo_actual = ""

creador_actual = ""

ruta_actual = ""

duracion_actual = 0

playlist_activa = False

skip_solicitado = False

salir_servidor = False

ventana_reproductor = None


# ============================================================
# BASE DE DATOS
# ============================================================

def conectar_db():

    conexion = sqlite3.connect(
        BASE_DATOS,
        timeout=30
    )

    conexion.row_factory = sqlite3.Row

    return conexion


def inicializar_db():

    conexion = conectar_db()

    cursor = conexion.cursor()


    cursor.execute("""
        CREATE TABLE IF NOT EXISTS cola (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            video_id TEXT NOT NULL,
            titulo TEXT DEFAULT '',
            creador TEXT DEFAULT '',
            url TEXT DEFAULT '',
            ruta TEXT DEFAULT '',
            creado_en REAL DEFAULT 0
        )
    """)


    conexion.commit()


    cursor.execute(
        "PRAGMA table_info(cola)"
    )


    columnas = {
        fila["name"]
        for fila in cursor.fetchall()
    }


    columnas_necesarias = {

        "video_id":
            "TEXT",

        "titulo":
            "TEXT DEFAULT ''",

        "creador":
            "TEXT DEFAULT ''",

        "url":
            "TEXT DEFAULT ''",

        "ruta":
            "TEXT DEFAULT ''",

        "creado_en":
            "REAL DEFAULT 0"
    }


    for nombre, tipo in columnas_necesarias.items():

        if nombre not in columnas:

            print(
                f"[BASE DE DATOS] "
                f"Añadiendo columna: {nombre}"
            )

            cursor.execute(
                f"ALTER TABLE cola "
                f"ADD COLUMN {nombre} {tipo}"
            )


    conexion.commit()

    conexion.close()


def agregar_a_cola(
    video_id,
    titulo="",
    creador="",
    url=""
):

    conexion = conectar_db()

    cursor = conexion.cursor()


    cursor.execute(
        """
        INSERT INTO cola (
            video_id,
            titulo,
            creador,
            url,
            ruta,
            creado_en
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            video_id,
            titulo,
            creador,
            url,
            "",
            time.time()
        )
    )


    conexion.commit()

    conexion.close()


def sacar_siguiente_cola():

    conexion = conectar_db()

    cursor = conexion.cursor()


    cursor.execute(
        """
        SELECT
            id,
            video_id,
            titulo,
            creador,
            url,
            ruta
        FROM cola
        ORDER BY id ASC
        LIMIT 1
        """
    )


    fila = cursor.fetchone()


    if not fila:

        conexion.close()

        return None


    cursor.execute(
        "DELETE FROM cola WHERE id = ?",
        (fila["id"],)
    )


    conexion.commit()

    conexion.close()


    return dict(fila)


def limpiar_cola():

    conexion = conectar_db()

    cursor = conexion.cursor()

    cursor.execute(
        "DELETE FROM cola"
    )

    conexion.commit()

    conexion.close()


def cantidad_cola():

    conexion = conectar_db()

    cursor = conexion.cursor()


    cursor.execute(
        "SELECT COUNT(*) AS cantidad "
        "FROM cola"
    )


    fila = cursor.fetchone()

    conexion.close()


    return int(
        fila["cantidad"]
    )


# ============================================================
# UTILIDADES
# ============================================================

def limpiar_error(error):

    texto = str(error)


    texto = re.sub(
        r'(?i)(cookie|token|authorization|password)=\S+',
        r'\1=***',
        texto
    )


    return texto[:1000]


def cambiar_estado(
    valor,
    video_id="",
    titulo="",
    creador="",
    ruta="",
    duracion=0
):

    global reproduciendo
    global video_actual
    global titulo_actual
    global creador_actual
    global ruta_actual
    global duracion_actual


    with estado_lock:

        reproduciendo = valor

        video_actual = video_id

        titulo_actual = titulo

        creador_actual = creador

        ruta_actual = ruta

        duracion_actual = duracion


def comprobar_reproduccion():

    with estado_lock:

        return reproduciendo


def contiene_karaoke(titulo):

    if not titulo:

        return False


    return (
        "karaoke"
        in titulo.lower()
    )


# ============================================================
# IP LOCAL
# ============================================================

def obtener_ip_lan():

    try:

        socket_local = socket.socket(
            socket.AF_INET,
            socket.SOCK_DGRAM
        )


        socket_local.connect(
            ("8.8.8.8", 80)
        )


        ip = socket_local.getsockname()[0]

        socket_local.close()


        return ip

    except Exception:

        return "127.0.0.1"


# ============================================================
# DURACIÓN
# ============================================================

def obtener_duracion(ruta):

    try:

        resultado = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                ruta
            ],
            capture_output=True,
            text=True,
            timeout=15
        )


        texto = (
            resultado.stdout or ""
        ).strip()


        duracion = float(
            texto
        )


        if duracion > 0:

            return duracion


    except Exception:

        pass


    return 0


# ============================================================
# VENTANA DEL REPRODUCTOR
# ============================================================

def obtener_ventana_activa():

    if not sys.platform.startswith("win"):

        return None


    try:

        return (
            ctypes
            .windll
            .user32
            .GetForegroundWindow()
        )


    except Exception:

        return None


def abrir_reproductor_predeterminado(
    ruta
):

    global ventana_reproductor


    if not os.path.exists(ruta):

        raise FileNotFoundError(
            f"No existe el archivo: {ruta}"
        )


    if sys.platform.startswith("win"):

        os.startfile(ruta)

        time.sleep(1)

        ventana_reproductor = (
            obtener_ventana_activa()
        )


        print(
            "[MEDIA] Ventana detectada:",
            ventana_reproductor
        )


    elif sys.platform == "darwin":

        subprocess.Popen(
            ["open", ruta]
        )


    else:

        subprocess.Popen(
            ["xdg-open", ruta]
        )


# ============================================================
# DETENER REPRODUCTOR
# ============================================================

def detener_reproduccion_windows():

    global ventana_reproductor


    if not sys.platform.startswith("win"):

        return


    # --------------------------------------------------------
    # APPCOMMAND MEDIA STOP
    # --------------------------------------------------------

    try:

        if ventana_reproductor:

            WM_APPCOMMAND = 0x0319

            APPCOMMAND_MEDIA_STOP = 13


            comando = (
                APPCOMMAND_MEDIA_STOP
                << 16
            )


            ctypes.windll.user32.SendMessageW(
                ventana_reproductor,
                WM_APPCOMMAND,
                0,
                comando
            )


            print(
                "[MEDIA] STOP enviado al reproductor."
            )


            time.sleep(0.3)


    except Exception as e:

        print(
            "[MEDIA] Error STOP:",
            e
        )


    # --------------------------------------------------------
    # TECLA MULTIMEDIA STOP
    # --------------------------------------------------------

    try:

        VK_MEDIA_STOP = 0xB2

        KEYEVENTF_KEYUP = 0x0002


        ctypes.windll.user32.keybd_event(
            VK_MEDIA_STOP,
            0,
            0,
            0
        )


        ctypes.windll.user32.keybd_event(
            VK_MEDIA_STOP,
            0,
            KEYEVENTF_KEYUP,
            0
        )


        print(
            "[MEDIA] Tecla multimedia STOP enviada."
        )


    except Exception as e:

        print(
            "[MEDIA] Error tecla STOP:",
            e
        )


# ============================================================
# REPRODUCCIÓN
# ============================================================

def reproducir_archivo(
    ruta,
    video_id,
    titulo,
    creador
):

    global skip_solicitado
    global ventana_reproductor


    duracion = obtener_duracion(
        ruta
    )


    skip_solicitado = False


    cambiar_estado(
        True,
        video_id,
        titulo,
        creador,
        ruta,
        duracion
    )


    print()

    print(
        "======================================"
    )

    print(
        "           REPRODUCIENDO"
    )

    print(
        "======================================"
    )


    print(
        f"Título: {titulo}"
    )


    print(
        f"Creador: {creador}"
    )


    if contiene_karaoke(titulo):

        print(
            "Tipo: VÍDEO KARAOKE"
        )

    else:

        print(
            "Tipo: AUDIO"
        )


    print(
        f"Archivo: {ruta}"
    )


    try:

        abrir_reproductor_predeterminado(
            ruta
        )


    except Exception as e:

        print(
            "[MEDIA] Error:",
            e
        )


        cambiar_estado(False)

        return


    # --------------------------------------------------------
    # ESPERAR
    # --------------------------------------------------------

    if duracion > 0:

        inicio = time.time()


        while True:

            if skip_solicitado:

                print(
                    "[MEDIA] SKIP detectado."
                )

                break


            if salir_servidor:

                break


            transcurrido = (
                time.time()
                - inicio
            )


            if transcurrido >= (
                duracion + 1.5
            ):

                break


            time.sleep(0.2)


    else:

        while True:

            if skip_solicitado:

                break


            if salir_servidor:

                break


            time.sleep(0.2)


    # --------------------------------------------------------
    # FINAL
    # --------------------------------------------------------

    if skip_solicitado:

        detener_reproduccion_windows()


        print(
            "[MEDIA] Canción saltada."
        )


    elif salir_servidor:

        detener_reproduccion_windows()


    else:

        print(
            "[MEDIA] Reproducción terminada."
        )


    skip_solicitado = False


    cambiar_estado(False)


    ventana_reproductor = None


# ============================================================
# INFORMACIÓN YOUTUBE
# ============================================================

def obtener_info_video(
    video_id
):

    url = (
        "https://www.youtube.com/watch?v="
        + video_id
    )


    opciones = {

        "quiet":
            True,

        "no_warnings":
            True,

        "skip_download":
            True,

        "noplaylist":
            True
    }


    with yt_dlp.YoutubeDL(
        opciones
    ) as ydl:

        return ydl.extract_info(
            url,
            download=False
        )


# ============================================================
# DESCARGA
# ============================================================

def descargar_video_o_audio(
    video_id,
    info
):

    titulo = (
        info.get("title")
        or video_id
    )


    creador = (
        info.get("uploader")
        or info.get("channel")
        or "Desconocido"
    )


    url = (
        info.get("webpage_url")
        or
        "https://www.youtube.com/watch?v="
        + video_id
    )


    # --------------------------------------------------------
    # KARAOKE -> MP4
    # --------------------------------------------------------

    if contiene_karaoke(titulo):

        archivo_final = os.path.join(
            CARPETA_VIDEOS,
            f"{video_id}.mp4"
        )


        print()

        print(
            "[DESCARGA] KARAOKE detectado."
        )


        print(
            "[DESCARGA] Vídeo + audio."
        )


        if not os.path.exists(
            archivo_final
        ):

            opciones = {

                "format":
                    "bestvideo+bestaudio/best",

                "outtmpl":
                    os.path.join(
                        CARPETA_VIDEOS,
                        f"{video_id}.%(ext)s"
                    ),

                "noplaylist":
                    True,

                "quiet":
                    False,

                "no_warnings":
                    False,

                "merge_output_format":
                    "mp4"
            }


            with yt_dlp.YoutubeDL(
                opciones
            ) as ydl:

                ydl.download(
                    [url]
                )


        if not os.path.exists(
            archivo_final
        ):

            posibles = []


            for nombre in os.listdir(
                CARPETA_VIDEOS
            ):

                if nombre.startswith(
                    video_id + "."
                ):

                    posibles.append(
                        os.path.join(
                            CARPETA_VIDEOS,
                            nombre
                        )
                    )


            if posibles:

                archivo_final = (
                    posibles[0]
                )

            else:

                raise RuntimeError(
                    "No apareció el vídeo descargado."
                )


        return (
            archivo_final,
            titulo,
            creador,
            url
        )


    # --------------------------------------------------------
    # NORMAL -> MP3
    # --------------------------------------------------------

    archivo_final = os.path.join(
        CARPETA_DESCARGAS,
        f"{video_id}.mp3"
    )


    print()

    print(
        "[DESCARGA] No es karaoke."
    )


    print(
        "[DESCARGA] Solo audio."
    )


    if not os.path.exists(
        archivo_final
    ):

        opciones = {

            "format":
                "bestaudio/best",

            "outtmpl":
                os.path.join(
                    CARPETA_DESCARGAS,
                    f"{video_id}.%(ext)s"
                ),

            "noplaylist":
                True,

            "quiet":
                False,

            "no_warnings":
                False,

            "postprocessors": [

                {

                    "key":
                        "FFmpegExtractAudio",

                    "preferredcodec":
                        "mp3",

                    "preferredquality":
                        "192"
                }
            ]
        }


        with yt_dlp.YoutubeDL(
            opciones
        ) as ydl:

            ydl.download(
                [url]
            )


    if not os.path.exists(
        archivo_final
    ):

        raise RuntimeError(
            "No apareció el MP3 descargado."
        )


    return (
        archivo_final,
        titulo,
        creador,
        url
    )


# ============================================================
# PREPARAR Y REPRODUCIR
# ============================================================

def preparar_y_reproducir(
    video_id,
    info=None
):

    try:

        with descarga_lock:

            if info is None:

                info = obtener_info_video(
                    video_id
                )


            (
                ruta,
                titulo,
                creador,
                url
            ) = descargar_video_o_audio(
                video_id,
                info
            )


        with reproduccion_lock:

            reproducir_archivo(
                ruta,
                video_id,
                titulo,
                creador
            )


        return {

            "ok":
                True,

            "titulo":
                titulo,

            "creador":
                creador,

            "url":
                url,

            "archivo":
                ruta
        }


    except Exception as e:

        print(
            "[ERROR]",
            limpiar_error(e)
        )


        cambiar_estado(False)


        return {

            "ok":
                False,

            "error":
                limpiar_error(e)
        }


# ============================================================
# HILO PLAYLIST
# ============================================================

def reproductor_playlist():

    print(
        "[PLAYLIST] Hilo iniciado."
    )


    while not salir_servidor:

        try:

            if not playlist_activa:

                time.sleep(0.3)

                continue


            if comprobar_reproduccion():

                time.sleep(0.3)

                continue


            siguiente = (
                sacar_siguiente_cola()
            )


            if not siguiente:

                time.sleep(0.3)

                continue


            print()

            print(
                "[PLAYLIST] Reproduciendo siguiente:"
            )


            print(
                siguiente["titulo"]
            )


            preparar_y_reproducir(
                siguiente["video_id"]
            )


        except Exception as e:

            print(
                "[PLAYLIST] Error:",
                limpiar_error(e)
            )


            time.sleep(1)


# ============================================================
# TERMINAL
# ============================================================

def terminal():

    global playlist_activa
    global skip_solicitado
    global salir_servidor


    print()

    print(
        "======================================"
    )

    print(
        "        COMANDOS DEL SERVIDOR"
    )

    print(
        "======================================"
    )

    print(
        "!skip"
    )

    print(
        "!playlist on"
    )

    print(
        "!playlist off"
    )

    print(
        "!estado"
    )

    print(
        "!cola"
    )

    print(
        "!limpiar"
    )

    print(
        "!salir"
    )

    print()


    playlist_activa = False


    print(
        "[PLAYLIST] DESACTIVADA al iniciar."
    )

    print()


    while not salir_servidor:

        try:

            comando = input(
                "> "
            ).strip()


        except (
            EOFError,
            KeyboardInterrupt
        ):

            break


        if not comando:

            continue


        comando_minusculas = (
            comando.lower()
        )


        # ------------------------------------------------------
        # SKIP
        # ------------------------------------------------------

        if comando_minusculas == "!skip":

            global_skip = comprobar_reproduccion()


            if not global_skip:

                print(
                    "[SKIP] No hay ninguna canción reproduciéndose."
                )

                continue


            print(
                "[SKIP] Saltando canción..."
            )


            skip_solicitado = True


            detener_reproduccion_windows()


        # ------------------------------------------------------
        # PLAYLIST ON
        # ------------------------------------------------------

        elif comando_minusculas == "!playlist on":

            playlist_activa = True


            print()

            print(
                "[PLAYLIST] ACTIVADA."
            )


            print(
                "[PLAYLIST] Las nuevas canciones "
                "se añadirán a la cola."
            )


            print(
                f"[PLAYLIST] Canciones en cola: "
                f"{cantidad_cola()}"
            )


        # ------------------------------------------------------
        # PLAYLIST OFF
        # ------------------------------------------------------

        elif comando_minusculas == "!playlist off":

            playlist_activa = False


            print()

            print(
                "[PLAYLIST] DESACTIVADA."
            )


            print(
                "[PLAYLIST] Las nuevas canciones "
                "se reproducirán directamente."
            )


            print(
                "[PLAYLIST] La cola existente "
                "no se reproducirá mientras OFF."
            )


        # ------------------------------------------------------
        # ESTADO
        # ------------------------------------------------------

        elif comando_minusculas == "!estado":

            with estado_lock:

                print()

                print(
                    "========== ESTADO =========="
                )


                print(
                    "Servidor: ACTIVO"
                )


                print(
                    "Playlist: "
                    + (
                        "ON"
                        if playlist_activa
                        else "OFF"
                    )
                )


                print(
                    "Reproduciendo: "
                    + (
                        "SÍ"
                        if reproduciendo
                        else "NO"
                    )
                )


                print(
                    f"Título: {titulo_actual}"
                )


                print(
                    f"Creador: {creador_actual}"
                )


                print(
                    f"Archivo: {ruta_actual}"
                )


                print(
                    f"Cola: {cantidad_cola()}"
                )


                print(
                    "============================"
                )


        # ------------------------------------------------------
        # COLA
        # ------------------------------------------------------

        elif comando_minusculas == "!cola":

            print()

            print(
                f"[PLAYLIST] Canciones en cola: "
                f"{cantidad_cola()}"
            )


        # ------------------------------------------------------
        # LIMPIAR
        # ------------------------------------------------------

        elif comando_minusculas == "!limpiar":

            limpiar_cola()


            print(
                "[PLAYLIST] Cola limpiada."
            )


        # ------------------------------------------------------
        # SALIR
        # ------------------------------------------------------

        elif comando_minusculas == "!salir":

            print(
                "[SERVIDOR] Cerrando..."
            )


            salir_servidor = True

            playlist_activa = False

            skip_solicitado = True


            detener_reproduccion_windows()


            time.sleep(0.5)


            os._exit(0)


        else:

            print(
                "[SERVIDOR] Comando desconocido."
            )


# ============================================================
# API CONECTADO
# ============================================================

@app.route(
    "/conectado",
    methods=["GET", "OPTIONS"]
)
def conectado():

    return jsonify({

        "ok":
            True,

        "conectado":
            True,

        "servidor":
            obtener_ip_lan(),

        "puerto":
            PORT
    })


# ============================================================
# API ESTADO
# ============================================================

@app.route(
    "/estado",
    methods=["GET"]
)
def estado():

    with estado_lock:

        return jsonify({

            "ok":
                True,

            "servidor":
                "TurboWarp YouTube",

            "puerto":
                PORT,

            "ip":
                obtener_ip_lan(),

            "reproduciendo":
                reproduciendo,

            "video":
                video_actual,

            "titulo":
                titulo_actual,

            "creador":
                creador_actual,

            "archivo":
                ruta_actual,

            "playlist":
                playlist_activa,

            "cola":
                cantidad_cola()
        })


# ============================================================
# API REPRODUCIENDO
# ============================================================

@app.route(
    "/reproduciendo",
    methods=["GET"]
)
def estado_reproduccion():

    return jsonify({

        "ok":
            True,

        "reproduciendo":
            comprobar_reproduccion()
    })


# ============================================================
# API BUSCAR
# ============================================================

@app.route(
    "/buscar",
    methods=["GET"]
)
def buscar():

    consulta = (
        request.args
        .get("q", "")
        .strip()
    )


    if not consulta:

        return jsonify({

            "ok":
                False,

            "error":
                "No has escrito nada para buscar."

        }), 400


    resultados = []


    opciones = {

        "quiet":
            True,

        "no_warnings":
            True,

        "skip_download":
            True,

        "extract_flat":
            True,

        "noplaylist":
            True
    }


    try:

        with yt_dlp.YoutubeDL(
            opciones
        ) as ydl:

            datos = ydl.extract_info(
                f"ytsearch100:{consulta}",
                download=False
            )


        entradas = (
            datos.get(
                "entries",
                []
            )
        )


        for entrada in entradas:

            if not entrada:

                continue


            video_id = (
                entrada.get("id")
            )


            if not video_id:

                continue


            url = (
                entrada.get(
                    "webpage_url"
                )
            )


            if not url:

                url = (
                    "https://www.youtube.com/watch?v="
                    + video_id
                )


            resultados.append({

                "id":
                    video_id,

                "titulo":
                    (
                        entrada.get("title")
                        or "Sin título"
                    ),

                "creador":
                    (
                        entrada.get("uploader")
                        or entrada.get("channel")
                        or "Desconocido"
                    ),

                "miniatura":
                    (
                        entrada.get("thumbnail")
                        or
                        f"https://i.ytimg.com/vi/"
                        f"{video_id}/hqdefault.jpg"
                    ),

                "url":
                    url
            })


            if len(resultados) >= 100:

                break


        return jsonify({

            "ok":
                True,

            "consulta":
                consulta,

            "resultados":
                resultados
        })


    except Exception as e:

        return jsonify({

            "ok":
                False,

            "error":
                limpiar_error(e)

        }), 500


# ============================================================
# API REPRODUCIR
# ============================================================

@app.route(
    "/reproducir",
    methods=["GET"]
)
def reproducir():

    video_id = (
        request.args
        .get("id", "")
        .strip()
    )


    if not re.fullmatch(
        r"[A-Za-z0-9_-]{11}",
        video_id
    ):

        return jsonify({

            "ok":
                False,

            "error":
                "ID de vídeo no válido."

        }), 400


    # --------------------------------------------------------
    # OBTENER INFORMACIÓN UNA SOLA VEZ
    # --------------------------------------------------------

    try:

        info = obtener_info_video(
            video_id
        )


        titulo = (
            info.get("title")
            or video_id
        )


        creador = (
            info.get("uploader")
            or info.get("channel")
            or "Desconocido"
        )


        url = (
            info.get("webpage_url")
            or
            "https://www.youtube.com/watch?v="
            + video_id
        )


    except Exception as e:

        return jsonify({

            "ok":
                False,

            "error":
                limpiar_error(e)

        }), 500


    # ========================================================
    # PLAYLIST OFF
    #
    # NO SE AÑADE A COLA
    #
    # SI HAY UNA CANCIÓN:
    # SKIP AUTOMÁTICO
    # ========================================================

    if not playlist_activa:

        global skip_solicitado


        if comprobar_reproduccion():

            print()

            print(
                "[PLAYLIST OFF] "
                "Ya hay una canción reproduciéndose."
            )


            print(
                "[PLAYLIST OFF] "
                "Ejecutando SKIP automático..."
            )


            skip_solicitado = True


            detener_reproduccion_windows()


            time.sleep(0.5)


        def tarea_directa():

            preparar_y_reproducir(
                video_id,
                info
            )


        hilo = threading.Thread(
            target=tarea_directa,
            daemon=True
        )


        hilo.start()


        print()

        print(
            "[PLAYLIST OFF] Reproducción directa:"
        )


        print(
            titulo
        )


        return jsonify({

            "ok":
                True,

            "en_cola":
                False,

            "titulo":
                titulo,

            "creador":
                creador,

            "url":
                url,

            "reproduciendo":
                True
        })


    # ========================================================
    # PLAYLIST ON
    # ========================================================

    agregar_a_cola(
        video_id,
        titulo,
        creador,
        url
    )


    posicion = (
        cantidad_cola()
    )


    print()

    print(
        "[PLAYLIST ON] Añadido a cola:"
    )


    print(
        titulo
    )


    print(
        f"Posición: {posicion}"
    )


    return jsonify({

        "ok":
            True,

        "en_cola":
            True,

        "titulo":
            titulo,

        "creador":
            creador,

        "url":
            url,

        "posicion":
            posicion,

        "reproduciendo":
            comprobar_reproduccion()
    })


# ============================================================
# API SKIP
# ============================================================

@app.route(
    "/skip",
    methods=["GET"]
)
def api_skip():

    global skip_solicitado


    if not comprobar_reproduccion():

        return jsonify({

            "ok":
                False,

            "error":
                "No hay ninguna canción reproduciéndose."

        }), 400


    print(
        "[API] SKIP solicitado."
    )


    skip_solicitado = True


    detener_reproduccion_windows()


    return jsonify({

        "ok":
            True,

        "skip":
            True
    })


# ============================================================
# API PLAYLIST
# ============================================================

@app.route(
    "/playlist",
    methods=["GET"]
)
def api_playlist():

    global playlist_activa


    modo = (
        request.args
        .get("modo", "")
        .strip()
        .lower()
    )


    if modo == "on":

        playlist_activa = True


        print(
            "[API] PLAYLIST ACTIVADA."
        )


        return jsonify({

            "ok":
                True,

            "playlist":
                True
        })


    if modo == "off":

        playlist_activa = False


        print(
            "[API] PLAYLIST DESACTIVADA."
        )


        return jsonify({

            "ok":
                True,

            "playlist":
                False
        })


    return jsonify({

        "ok":
            True,

        "playlist":
            playlist_activa,

        "cola":
            cantidad_cola()
    })


# ============================================================
# API DETENER
# ============================================================

@app.route(
    "/detener",
    methods=["GET"]
)
def detener():

    global skip_solicitado


    skip_solicitado = True


    detener_reproduccion_windows()


    cambiar_estado(
        False
    )


    return jsonify({

        "ok":
            True,

        "reproduciendo":
            False
    })


# ============================================================
# API ABRIR
# ============================================================

@app.route(
    "/abrir",
    methods=["GET"]
)
def abrir():

    ruta = (
        request.args
        .get("ruta", "")
        .strip()
    )


    if not ruta:

        return jsonify({

            "ok":
                False,

            "error":
                "Falta la ruta."

        }), 400


    if not os.path.exists(
        ruta
    ):

        return jsonify({

            "ok":
                False,

            "error":
                "El archivo no existe."

        }), 404


    try:

        abrir_reproductor_predeterminado(
            ruta
        )


        return jsonify({
            "ok": True
        })


    except Exception as e:

        return jsonify({

            "ok":
                False,

            "error":
                limpiar_error(e)

        }), 500


# ============================================================
# INICIO
# ============================================================

if __name__ == "__main__":

    inicializar_db()


    playlist_activa = False


    limpiar_cola()


    ip_lan = obtener_ip_lan()


    print()

    print(
        "======================================"
    )

    print(
        "       SERVIDOR TURBOWARP"
    )

    print(
        "       YOUTUBE + PLAYLIST"
    )

    print(
        "======================================"
    )

    print()


    print(
        f"IP LAN: {ip_lan}"
    )


    print(
        f"Puerto: {PORT}"
    )


    print()


    print(
        "Desde este PC:"
    )


    print(
        f"http://127.0.0.1:{PORT}/conectado"
    )


    print()


    print(
        "Desde otros dispositivos:"
    )


    print(
        f"http://{ip_lan}:{PORT}/conectado"
    )


    print()


    print(
        "Playlist al iniciar: OFF"
    )


    print()


    print(
        "Audio:"
    )


    print(
        CARPETA_DESCARGAS
    )


    print()


    print(
        "Vídeos karaoke:"
    )


    print(
        CARPETA_VIDEOS
    )


    print()


    print(
        "======================================"
    )


    print(
        "REGLA DE DESCARGA"
    )


    print(
        "======================================"
    )


    print(
        "Título contiene 'karaoke'"
    )


    print(
        "-> Vídeo + audio (.mp4)"
    )


    print()


    print(
        "Título NO contiene 'karaoke'"
    )


    print(
        "-> Solo audio (.mp3)"
    )


    print()


    # ========================================================
    # HILO PLAYLIST
    # ========================================================

    hilo_playlist = threading.Thread(
        target=reproductor_playlist,
        daemon=True
    )


    hilo_playlist.start()


    # ========================================================
    # HILO TERMINAL
    # ========================================================

    hilo_terminal = threading.Thread(
        target=terminal,
        daemon=True
    )


    hilo_terminal.start()


    # ========================================================
    # FLASK
    # ========================================================

    app.run(
        host=HOST,
        port=PORT,
        debug=False,
        threaded=True
    )