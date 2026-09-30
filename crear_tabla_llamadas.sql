/* ============================================================
   Módulo LLAMADAS — Notificadores SAT
   Tabla: BDSGTM01.dbo.LlamadasContribuyentes
   Registra el resultado de cada llamada a un contribuyente de la
   cartera OP/RD (identificador + codNotificador).

   Ejecutar UNA sola vez en el servidor (BDSGTM01) antes de activar
   la nueva app. No altera ninguna tabla existente.
   ============================================================ */

IF OBJECT_ID(N'BDSGTM01.dbo.LlamadasContribuyentes', N'U') IS NULL
BEGIN
    CREATE TABLE BDSGTM01.dbo.LlamadasContribuyentes (
        id               INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CodContribuyente VARCHAR(11)       NOT NULL,
        identificador    INT               NOT NULL,   -- YYYYMMDD de la lista OP/RD
        codNotificador   INT               NOT NULL,   -- id del notificador en Fiscalizadores
        idOriginalCartera INT              NOT NULL,   -- id ancla en CarteraNotificacionesOPRD
        FecRegistro      DATETIME          NOT NULL,   -- hora del servidor
        Resultado        VARCHAR(20)       NOT NULL,   -- 'Atendida' | 'No contestada' | 'Numero no existe'
        Compromiso       VARCHAR(40)       NULL,       -- 'Vendra a pagar' | 'No acepta la deuda'
        FechaCompromiso  DATE              NULL,       -- obligatoria si Compromiso='Vendra a pagar'
        Observaciones    VARCHAR(2000)     NULL,
        IdempotenciaKey  VARCHAR(64)       NULL,       -- UUID de la app: evita duplicados en reintentos
        FechaCaptura     DATETIME          NULL        -- hora local del equipo (información)
    );

    CREATE INDEX IX_Llamadas_Cartera
        ON BDSGTM01.dbo.LlamadasContribuyentes (identificador, codNotificador);

    CREATE UNIQUE INDEX UQ_Llamadas_Idempotencia
        ON BDSGTM01.dbo.LlamadasContribuyentes (IdempotenciaKey)
        WHERE IdempotenciaKey IS NOT NULL;
END
GO