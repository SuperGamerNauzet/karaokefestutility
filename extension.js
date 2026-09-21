(function (Scratch) {
    "use strict";


    // ============================================================
    // CONFIGURACIÓN DEL SERVIDOR
    // ============================================================

    let SERVER_IP = "127.0.0.1";

    const SERVER_PORT = 8765;


    // ============================================================
    // URL DEL SERVIDOR
    // ============================================================

    function obtenerURLBase() {

        return (
            "http://" +
            SERVER_IP +
            ":" +
            SERVER_PORT
        );
    }


    // ============================================================
    // FETCH COMPATIBLE CON TURBOWARP
    // ============================================================

    async function hacerFetch(
        url,
        opciones = {}
    ) {

        if (
            typeof Scratch.fetch === "function"
        ) {

            return await Scratch.fetch(
                url,
                opciones
            );
        }


        return await fetch(
            url,
            opciones
        );
    }


    // ============================================================
    // EXTENSIÓN
    // ============================================================

    class YouTubeTurboWarp {

        constructor() {

            this.resultados = [];

            // Variables internas.
            // Se usa "_" para que no choquen con los
            // nombres de los opcodes/reporters.

            this._ultimaURL = "";
            this._ultimoTitulo = "";
            this._ultimoCreador = "";

            this._estado = "Listo";

            this.panel = null;
            this.lista = null;
            this.estadoElemento = null;
        }


        // ========================================================
        // INFORMACIÓN
        // ========================================================

        getInfo() {

            return {

                id: "youtubeLocalPC",

                name: "YouTube PC",

                color1: "#ff0000",
                color2: "#cc0000",
                color3: "#990000",


                blocks: [

                    {
                        opcode: "buscar",

                        blockType:
                            Scratch.BlockType.COMMAND,

                        text:
                            "Buscar [CONSULTA]",

                        arguments: {

                            CONSULTA: {

                                type:
                                    Scratch.ArgumentType.STRING,

                                defaultValue:
                                    "tumbao"
                            }
                        }
                    },


                    {
                        opcode: "ultimaURL",

                        blockType:
                            Scratch.BlockType.REPORTER,

                        text:
                            "último link del vídeo"
                    },


                    {
                        opcode: "ultimoTitulo",

                        blockType:
                            Scratch.BlockType.REPORTER,

                        text:
                            "último título"
                    },


                    {
                        opcode: "ultimoCreador",

                        blockType:
                            Scratch.BlockType.REPORTER,

                        text:
                            "último creador"
                    },


                    {
                        opcode: "estaReproduciendo",

                        blockType:
                            Scratch.BlockType.BOOLEAN,

                        text:
                            "¿se está reproduciendo?"
                    },


                    {
                        opcode: "conectadoServidor",

                        blockType:
                            Scratch.BlockType.BOOLEAN,

                        text:
                            "¿connected to server?"
                    },


                    {
                        opcode: "establecerIPServidor",

                        blockType:
                            Scratch.BlockType.COMMAND,

                        text:
                            "set server ip [IP]",

                        arguments: {

                            IP: {

                                type:
                                    Scratch.ArgumentType.STRING,

                                defaultValue:
                                    "127.0.0.1"
                            }
                        }
                    },


                    {
                        opcode: "estado",

                        blockType:
                            Scratch.BlockType.REPORTER,

                        text:
                            "estado de YouTube"
                    },


                    {
                        opcode: "cerrar",

                        blockType:
                            Scratch.BlockType.COMMAND,

                        text:
                            "cerrar resultados"
                    }
                ]
            };
        }


        // ========================================================
        // SET SERVER IP
        // ========================================================

        establecerIPServidor(args) {

            let ip =
                String(
                    args.IP || ""
                ).trim();


            if (!ip) {

                return;
            }


            // Quitar protocolo si lo escribe.
            ip =
                ip.replace(
                    /^https?:\/\//i,
                    ""
                );


            // Quitar cualquier ruta.
            ip =
                ip.split("/")[0];


            // Quitar :8765 si el usuario lo escribe.
            if (
                ip.endsWith(
                    ":" + SERVER_PORT
                )
            ) {

                ip =
                    ip.substring(
                        0,
                        ip.length -
                        (
                            String(
                                SERVER_PORT
                            ).length + 1
                        )
                    );
            }


            SERVER_IP = ip.trim();


            this._estado =
                "Servidor: " +
                obtenerURLBase();


            this.actualizarEstado();


            console.log(
                "[YouTube PC] Servidor:",
                obtenerURLBase()
            );
        }


        // ========================================================
        // BUSCAR
        // ========================================================

        async buscar(args) {

            const consulta =
                String(
                    args.CONSULTA || ""
                ).trim();


            if (!consulta) {

                return;
            }


            this.crearPanel();


            this._estado =
                "Buscando...";


            this.actualizarEstado();


            this.lista.innerHTML = "";


            try {

                const respuesta =
                    await hacerFetch(

                        obtenerURLBase() +
                        "/buscar?q=" +
                        encodeURIComponent(
                            consulta
                        )
                    );


                const datos =
                    await respuesta.json();


                if (!datos.ok) {

                    this._estado =
                        "Error: " +
                        (
                            datos.error ||
                            "Error desconocido"
                        );


                    this.actualizarEstado();


                    return;
                }


                this.resultados =
                    datos.resultados || [];


                if (
                    this.resultados.length === 0
                ) {

                    this._estado =
                        "No se encontraron resultados.";


                    this.actualizarEstado();


                    return;
                }


                this._estado =
                    this.resultados.length +
                    " resultados encontrados";


                this.actualizarEstado();


                this.mostrarResultados();

            } catch (error) {

                this._estado =
                    "No se pudo conectar con Python.";

                this.actualizarEstado();

                console.error(
                    "[YouTube PC]",
                    error
                );
            }
        }


        // ========================================================
        // CREAR PANEL
        // ========================================================

        crearPanel() {

            if (this.panel) {

                this.panel.remove();
            }


            this.panel =
                document.createElement(
                    "div"
                );


            this.panel.style.position =
                "fixed";

            this.panel.style.left =
                "50%";

            this.panel.style.top =
                "50%";

            this.panel.style.transform =
                "translate(-50%, -50%)";

            this.panel.style.width =
                "700px";

            this.panel.style.maxWidth =
                "90vw";

            this.panel.style.height =
                "650px";

            this.panel.style.maxHeight =
                "90vh";

            this.panel.style.background =
                "#181818";

            this.panel.style.color =
                "white";

            this.panel.style.borderRadius =
                "15px";

            this.panel.style.boxShadow =
                "0 10px 40px rgba(0,0,0,0.6)";

            this.panel.style.zIndex =
                "999999";

            this.panel.style.fontFamily =
                "Arial, sans-serif";


            document.body.appendChild(
                this.panel
            );


            // ====================================================
            // CABECERA
            // ====================================================

            const cabecera =
                document.createElement(
                    "div"
                );


            cabecera.style.height =
                "70px";

            cabecera.style.display =
                "flex";

            cabecera.style.alignItems =
                "center";

            cabecera.style.padding =
                "0 20px";

            cabecera.style.boxSizing =
                "border-box";

            cabecera.style.background =
                "#242424";

            cabecera.style.borderRadius =
                "15px 15px 0 0";


            this.panel.appendChild(
                cabecera
            );


            // ====================================================
            // TÍTULO
            // ====================================================

            const titulo =
                document.createElement(
                    "div"
                );


            titulo.textContent =
                "🎵 YouTube";


            titulo.style.fontSize =
                "22px";


            titulo.style.fontWeight =
                "bold";


            cabecera.appendChild(
                titulo
            );


            // ====================================================
            // CERRAR
            // ====================================================

            const cerrar =
                document.createElement(
                    "button"
                );


            cerrar.textContent =
                "✕";


            cerrar.style.marginLeft =
                "auto";


            cerrar.style.background =
                "#ff3333";


            cerrar.style.color =
                "white";


            cerrar.style.border =
                "none";


            cerrar.style.borderRadius =
                "8px";


            cerrar.style.padding =
                "10px 15px";


            cerrar.style.cursor =
                "pointer";


            cerrar.onclick =
                () => this.cerrarPanel();


            cabecera.appendChild(
                cerrar
            );


            // ====================================================
            // ESTADO
            // ====================================================

            this.estadoElemento =
                document.createElement(
                    "div"
                );


            this.estadoElemento.style.padding =
                "10px 20px";


            this.estadoElemento.style.background =
                "#101010";


            this.estadoElemento.style.fontSize =
                "14px";


            this.estadoElemento.textContent =
                this._estado;


            this.panel.appendChild(
                this.estadoElemento
            );


            // ====================================================
            // LISTA
            // ====================================================

            this.lista =
                document.createElement(
                    "div"
                );


            this.lista.style.height =
                "calc(100% - 120px)";


            this.lista.style.overflowY =
                "auto";


            this.lista.style.padding =
                "15px";


            this.lista.style.boxSizing =
                "border-box";


            this.panel.appendChild(
                this.lista
            );
        }


        // ========================================================
        // MOSTRAR RESULTADOS
        // ========================================================

        mostrarResultados() {

            this.lista.innerHTML = "";


            for (
                const video
                of this.resultados
            ) {

                const tarjeta =
                    document.createElement(
                        "div"
                    );


                tarjeta.style.display =
                    "flex";


                tarjeta.style.gap =
                    "15px";


                tarjeta.style.padding =
                    "12px";


                tarjeta.style.marginBottom =
                    "10px";


                tarjeta.style.background =
                    "#292929";


                tarjeta.style.borderRadius =
                    "10px";


                tarjeta.style.cursor =
                    "pointer";


                tarjeta.style.transition =
                    "background 0.15s";


                tarjeta.onmouseenter =
                    () => {

                        tarjeta.style.background =
                            "#3a3a3a";
                    };


                tarjeta.onmouseleave =
                    () => {

                        tarjeta.style.background =
                            "#292929";
                    };


                // =================================================
                // MINIATURA
                // =================================================

                const imagen =
                    document.createElement(
                        "img"
                    );


                imagen.src =
                    video.miniatura;


                imagen.style.width =
                    "180px";


                imagen.style.height =
                    "100px";


                imagen.style.objectFit =
                    "cover";


                imagen.style.borderRadius =
                    "8px";


                imagen.onerror =
                    () => {

                        imagen.style.display =
                            "none";
                    };


                tarjeta.appendChild(
                    imagen
                );


                // =================================================
                // INFORMACIÓN
                // =================================================

                const informacion =
                    document.createElement(
                        "div"
                    );


                informacion.style.flex =
                    "1";


                informacion.style.minWidth =
                    "0";


                // =================================================
                // TÍTULO
                // =================================================

                const titulo =
                    document.createElement(
                        "div"
                    );


                titulo.textContent =
                    video.titulo;


                titulo.style.fontSize =
                    "17px";


                titulo.style.fontWeight =
                    "bold";


                titulo.style.marginBottom =
                    "8px";


                // =================================================
                // CREADOR
                // =================================================

                const creador =
                    document.createElement(
                        "div"
                    );


                creador.textContent =
                    "👤 " +
                    (
                        video.creador ||
                        "Desconocido"
                    );


                creador.style.color =
                    "#bbbbbb";


                informacion.appendChild(
                    titulo
                );


                informacion.appendChild(
                    creador
                );


                tarjeta.appendChild(
                    informacion
                );


                // =================================================
                // CLICK
                // =================================================

                tarjeta.onclick =
                    () => {

                        this.seleccionarVideo(
                            video
                        );
                    };


                this.lista.appendChild(
                    tarjeta
                );
            }
        }


        // ========================================================
        // SELECCIONAR VÍDEO
        // ========================================================

        async seleccionarVideo(video) {

            this._ultimaURL =
                video.url;


            this._ultimoTitulo =
                video.titulo;


            this._ultimoCreador =
                video.creador || "";


            this._estado =
                "Preparando: " +
                video.titulo;


            this.actualizarEstado();


            try {

                const respuesta =
                    await hacerFetch(

                        obtenerURLBase() +
                        "/reproducir?id=" +
                        encodeURIComponent(
                            video.id
                        )
                    );


                const datos =
                    await respuesta.json();


                if (!datos.ok) {

                    this._estado =
                        "Error: " +
                        (
                            datos.error ||
                            "No se pudo reproducir."
                        );


                    this.actualizarEstado();


                    return;
                }


                this._estado =
                    "▶ Reproduciendo: " +
                    (
                        datos.titulo ||
                        video.titulo
                    );


                this.actualizarEstado();


            } catch (error) {

                this._estado =
                    "Error conectando con Python.";


                this.actualizarEstado();


                console.error(
                    "[YouTube PC]",
                    error
                );
            }
        }


        // ========================================================
        // ¿SE ESTÁ REPRODUCIENDO?
        // ========================================================

        async estaReproduciendo() {

            try {

                const respuesta =
                    await hacerFetch(

                        obtenerURLBase() +
                        "/reproduciendo"
                    );


                const datos =
                    await respuesta.json();


                return Boolean(
                    datos.reproduciendo
                );


            } catch (error) {

                return false;
            }
        }


        // ========================================================
        // ¿CONECTADO?
        // ========================================================

        async conectadoServidor() {

            try {

                const respuesta =
                    await hacerFetch(

                        obtenerURLBase() +
                        "/conectado"
                    );


                if (!respuesta.ok) {

                    return false;
                }


                const datos =
                    await respuesta.json();


                return Boolean(
                    datos.conectado
                );


            } catch (error) {

                console.error(
                    "[YouTube PC] Error de conexión:",
                    error
                );

                return false;
            }
        }


        // ========================================================
        // ACTUALIZAR ESTADO
        // ========================================================

        actualizarEstado() {

            if (
                this.estadoElemento
            ) {

                this.estadoElemento.textContent =
                    this._estado;
            }
        }


        // ========================================================
        // CERRAR PANEL
        // ========================================================

        cerrarPanel() {

            if (this.panel) {

                this.panel.remove();

                this.panel = null;

                this.lista = null;

                this.estadoElemento = null;
            }
        }


        // ========================================================
        // CERRAR
        // ========================================================

        cerrar() {

            this.cerrarPanel();
        }


        // ========================================================
        // REPORTERS
        // ========================================================

        ultimaURL() {

            return this._ultimaURL;
        }


        ultimoTitulo() {

            return this._ultimoTitulo;
        }


        ultimoCreador() {

            return this._ultimoCreador;
        }


        estado() {

            return this._estado;
        }
    }


    // ============================================================
    // REGISTRAR
    // ============================================================

    Scratch.extensions.register(
        new YouTubeTurboWarp()
    );

})(Scratch);