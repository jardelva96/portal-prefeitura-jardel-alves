/* =============================================================================
   Portal Prefeitura Jardel Alves - Modelagem completa do banco
   SGBD: SQL Server 2022
   Convenções:
     - Tabelas em snake_case, singular
     - PK sempre "id" BIGINT IDENTITY
     - Timestamps created_at / updated_at / deleted_at (soft delete onde faz sentido)
     - FKs com sufixo _id
     - NVARCHAR para texto (suporte Unicode / pt-BR)
     - DECIMAL(18,2) para valores monetários
     - DATETIME2 para datas com hora
     - Índices em colunas de busca frequente e FKs
============================================================================= */

/* -----------------------------------------------------------------------------
   0. CRIAÇÃO DO BANCO
----------------------------------------------------------------------------- */
IF DB_ID('portal_prefeitura') IS NULL
    CREATE DATABASE portal_prefeitura
        COLLATE Latin1_General_CI_AI;
GO

USE portal_prefeitura;
GO

/* =============================================================================
   1. SEGURANÇA / AUTENTICAÇÃO
============================================================================= */

CREATE TABLE usuario (
    id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    username         NVARCHAR(100)  NOT NULL UNIQUE,
    email            NVARCHAR(255)  NOT NULL UNIQUE,
    password_hash    NVARCHAR(255)  NOT NULL,
    nome_completo    NVARCHAR(200)  NOT NULL,
    cpf              CHAR(11)       NULL UNIQUE,
    telefone         NVARCHAR(20)   NULL,
    ativo            BIT            NOT NULL DEFAULT 1,
    email_verificado BIT            NOT NULL DEFAULT 0,
    bloqueado        BIT            NOT NULL DEFAULT 0,
    tentativas_login INT            NOT NULL DEFAULT 0,
    ultimo_login_at  DATETIME2      NULL,
    created_at       DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at       DATETIME2      NULL,
    deleted_at       DATETIME2      NULL
);
CREATE INDEX ix_usuario_email ON usuario(email);
CREATE INDEX ix_usuario_cpf   ON usuario(cpf);

CREATE TABLE papel (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome       NVARCHAR(60)  NOT NULL UNIQUE, -- ROLE_ADMIN, ROLE_CIDADAO, ROLE_EDITOR, etc
    descricao  NVARCHAR(200) NULL,
    sistema    BIT           NOT NULL DEFAULT 0, -- papéis de sistema não podem ser excluídos
    created_at DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE permissao (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome       NVARCHAR(100) NOT NULL UNIQUE, -- ex: noticia:criar, esic:responder
    recurso    NVARCHAR(60)  NOT NULL,
    acao       NVARCHAR(40)  NOT NULL,
    descricao  NVARCHAR(200) NULL,
    created_at DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
CREATE INDEX ix_permissao_recurso ON permissao(recurso);

CREATE TABLE usuario_papel (
    usuario_id BIGINT NOT NULL,
    papel_id   BIGINT NOT NULL,
    PRIMARY KEY (usuario_id, papel_id),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id),
    FOREIGN KEY (papel_id)   REFERENCES papel(id)
);

CREATE TABLE papel_permissao (
    papel_id     BIGINT NOT NULL,
    permissao_id BIGINT NOT NULL,
    PRIMARY KEY (papel_id, permissao_id),
    FOREIGN KEY (papel_id)     REFERENCES papel(id),
    FOREIGN KEY (permissao_id) REFERENCES permissao(id)
);

CREATE TABLE refresh_token (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    usuario_id  BIGINT       NOT NULL,
    token       NVARCHAR(500) NOT NULL UNIQUE,
    expira_em   DATETIME2    NOT NULL,
    revogado    BIT          NOT NULL DEFAULT 0,
    ip          NVARCHAR(45) NULL,
    user_agent  NVARCHAR(500) NULL,
    created_at  DATETIME2    NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);
CREATE INDEX ix_refresh_token_usuario ON refresh_token(usuario_id);

CREATE TABLE password_reset_token (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    usuario_id BIGINT        NOT NULL,
    token      NVARCHAR(255) NOT NULL UNIQUE,
    expira_em  DATETIME2     NOT NULL,
    usado      BIT           NOT NULL DEFAULT 0,
    created_at DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);

/* =============================================================================
   2. AUDITORIA
============================================================================= */

CREATE TABLE audit_log (
    id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    usuario_id     BIGINT         NULL,
    acao           NVARCHAR(40)   NOT NULL, -- CREATE, UPDATE, DELETE, LOGIN, LOGOUT
    entidade       NVARCHAR(100)  NULL,
    entidade_id    NVARCHAR(100)  NULL,
    dados_antigos  NVARCHAR(MAX)  NULL,
    dados_novos    NVARCHAR(MAX)  NULL,
    ip             NVARCHAR(45)   NULL,
    user_agent     NVARCHAR(500)  NULL,
    created_at     DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);
CREATE INDEX ix_audit_log_entidade ON audit_log(entidade, entidade_id);
CREATE INDEX ix_audit_log_usuario  ON audit_log(usuario_id);
CREATE INDEX ix_audit_log_created  ON audit_log(created_at);

/* =============================================================================
   3. STORAGE (arquivos genéricos)
============================================================================= */

CREATE TABLE arquivo (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome_original   NVARCHAR(255)  NOT NULL,
    nome_armazenado NVARCHAR(255)  NOT NULL,
    caminho         NVARCHAR(500)  NOT NULL,
    mime_type       NVARCHAR(100)  NOT NULL,
    tamanho_bytes   BIGINT         NOT NULL,
    hash_sha256     CHAR(64)       NULL,
    modulo          NVARCHAR(60)   NULL,  -- noticia, esic, licitacao...
    referencia_id   BIGINT         NULL,
    created_by_id   BIGINT         NULL,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (created_by_id) REFERENCES usuario(id)
);
CREATE INDEX ix_arquivo_modulo ON arquivo(modulo, referencia_id);

/* =============================================================================
   4. INSTITUCIONAL
============================================================================= */

CREATE TABLE municipio (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome            NVARCHAR(150)  NOT NULL,
    uf              CHAR(2)        NOT NULL,
    cnpj            CHAR(14)       NOT NULL UNIQUE,
    codigo_ibge     CHAR(7)        NOT NULL UNIQUE,
    cep             CHAR(8)        NOT NULL,
    endereco        NVARCHAR(255)  NOT NULL,
    telefone        NVARCHAR(20)   NULL,
    email           NVARCHAR(255)  NULL,
    site            NVARCHAR(255)  NULL,
    populacao       INT            NULL,
    area_km2        DECIMAL(10,2)  NULL,
    fundacao        DATE           NULL,
    aniversario     DATE           NULL,
    gentilico       NVARCHAR(60)   NULL,
    latitude        DECIMAL(10,7)  NULL,
    longitude       DECIMAL(10,7)  NULL,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at      DATETIME2      NULL
);

CREATE TABLE simbolo_municipal (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    tipo        NVARCHAR(20)  NOT NULL, -- BANDEIRA, BRASAO, HINO
    titulo      NVARCHAR(150) NOT NULL,
    descricao   NVARCHAR(MAX) NULL,
    arquivo_id  BIGINT        NULL,
    letra       NVARCHAR(MAX) NULL,    -- para hino
    autor       NVARCHAR(200) NULL,
    created_at  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (arquivo_id) REFERENCES arquivo(id)
);

CREATE TABLE historia_secao (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    titulo     NVARCHAR(200)  NOT NULL,
    conteudo   NVARCHAR(MAX)  NOT NULL,
    ordem      INT            NOT NULL DEFAULT 0,
    imagem_id  BIGINT         NULL,
    ativo      BIT            NOT NULL DEFAULT 1,
    created_at DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at DATETIME2      NULL,
    FOREIGN KEY (imagem_id) REFERENCES arquivo(id)
);

CREATE TABLE prefeito (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome            NVARCHAR(200)  NOT NULL,
    partido         NVARCHAR(20)   NULL,
    mandato_inicio  DATE           NOT NULL,
    mandato_fim     DATE           NULL,
    biografia       NVARCHAR(MAX)  NULL,
    foto_id         BIGINT         NULL,
    email           NVARCHAR(255)  NULL,
    atual           BIT            NOT NULL DEFAULT 0,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at      DATETIME2      NULL,
    FOREIGN KEY (foto_id) REFERENCES arquivo(id)
);

CREATE TABLE vice_prefeito (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome            NVARCHAR(200)  NOT NULL,
    partido         NVARCHAR(20)   NULL,
    prefeito_id     BIGINT         NULL,
    mandato_inicio  DATE           NOT NULL,
    mandato_fim     DATE           NULL,
    biografia       NVARCHAR(MAX)  NULL,
    foto_id         BIGINT         NULL,
    email           NVARCHAR(255)  NULL,
    atual           BIT            NOT NULL DEFAULT 0,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (prefeito_id) REFERENCES prefeito(id),
    FOREIGN KEY (foto_id)     REFERENCES arquivo(id)
);

CREATE TABLE secretaria (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome         NVARCHAR(200)  NOT NULL,
    sigla        NVARCHAR(20)   NULL,
    descricao    NVARCHAR(MAX)  NULL,
    missao       NVARCHAR(MAX)  NULL,
    endereco     NVARCHAR(255)  NULL,
    telefone     NVARCHAR(20)   NULL,
    email        NVARCHAR(255)  NULL,
    horario      NVARCHAR(200)  NULL,
    ordem        INT            NOT NULL DEFAULT 0,
    ativo        BIT            NOT NULL DEFAULT 1,
    logo_id      BIGINT         NULL,
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at   DATETIME2      NULL,
    FOREIGN KEY (logo_id) REFERENCES arquivo(id)
);

CREATE TABLE secretario (
    id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    secretaria_id  BIGINT         NOT NULL,
    nome           NVARCHAR(200)  NOT NULL,
    cargo          NVARCHAR(100)  NOT NULL,
    biografia      NVARCHAR(MAX)  NULL,
    foto_id        BIGINT         NULL,
    email          NVARCHAR(255)  NULL,
    telefone       NVARCHAR(20)   NULL,
    posse_em       DATE           NULL,
    atual          BIT            NOT NULL DEFAULT 1,
    created_at     DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at     DATETIME2      NULL,
    FOREIGN KEY (secretaria_id) REFERENCES secretaria(id),
    FOREIGN KEY (foto_id)       REFERENCES arquivo(id)
);

CREATE TABLE organograma_no (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome        NVARCHAR(200) NOT NULL,
    tipo        NVARCHAR(40)  NOT NULL, -- PREFEITO, SECRETARIA, DEPARTAMENTO, SETOR
    pai_id      BIGINT        NULL,
    ordem       INT           NOT NULL DEFAULT 0,
    responsavel NVARCHAR(200) NULL,
    descricao   NVARCHAR(500) NULL,
    ativo       BIT           NOT NULL DEFAULT 1,
    created_at  DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (pai_id) REFERENCES organograma_no(id)
);

/* =============================================================================
   5. TRANSPARÊNCIA
============================================================================= */

CREATE TABLE receita (
    id                 BIGINT IDENTITY(1,1) PRIMARY KEY,
    exercicio          INT            NOT NULL,
    mes                TINYINT        NOT NULL,
    categoria          NVARCHAR(100)  NOT NULL, -- RECEITA CORRENTE, DE CAPITAL
    subcategoria       NVARCHAR(100)  NULL,
    fonte              NVARCHAR(200)  NULL,
    codigo             NVARCHAR(30)   NULL,
    descricao          NVARCHAR(300)  NOT NULL,
    valor_previsto     DECIMAL(18,2)  NOT NULL DEFAULT 0,
    valor_arrecadado   DECIMAL(18,2)  NOT NULL DEFAULT 0,
    created_at         DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
CREATE INDEX ix_receita_periodo ON receita(exercicio, mes);

CREATE TABLE despesa (
    id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    exercicio      INT            NOT NULL,
    mes            TINYINT        NOT NULL,
    orgao          NVARCHAR(200)  NOT NULL,
    funcao         NVARCHAR(100)  NULL,
    subfuncao      NVARCHAR(100)  NULL,
    categoria      NVARCHAR(100)  NULL,
    elemento       NVARCHAR(100)  NULL,
    credor         NVARCHAR(200)  NULL,
    cnpj_cpf       NVARCHAR(14)   NULL,
    descricao      NVARCHAR(300)  NOT NULL,
    empenho        NVARCHAR(30)   NULL,
    numero_empenho NVARCHAR(50)   NULL,
    valor_empenhado DECIMAL(18,2) NOT NULL DEFAULT 0,
    valor_liquidado DECIMAL(18,2) NOT NULL DEFAULT 0,
    valor_pago      DECIMAL(18,2) NOT NULL DEFAULT 0,
    created_at      DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);
CREATE INDEX ix_despesa_periodo ON despesa(exercicio, mes);
CREATE INDEX ix_despesa_orgao   ON despesa(orgao);
CREATE INDEX ix_despesa_credor  ON despesa(credor);

CREATE TABLE licitacao (
    id                BIGINT IDENTITY(1,1) PRIMARY KEY,
    numero            NVARCHAR(50)   NOT NULL,
    ano               INT            NOT NULL,
    modalidade        NVARCHAR(40)   NOT NULL, -- PREGAO, CONCORRENCIA, TOMADA_PRECO, CONVITE, DISPENSA, INEXIGIBILIDADE
    tipo              NVARCHAR(40)   NULL,     -- MENOR_PRECO, TECNICA_PRECO etc
    objeto            NVARCHAR(MAX)  NOT NULL,
    orgao             NVARCHAR(200)  NULL,
    secretaria_id     BIGINT         NULL,
    data_abertura     DATETIME2      NULL,
    data_publicacao   DATETIME2      NULL,
    data_homologacao  DATETIME2      NULL,
    valor_estimado    DECIMAL(18,2)  NULL,
    valor_homologado  DECIMAL(18,2)  NULL,
    status            NVARCHAR(30)   NOT NULL DEFAULT 'ABERTA',
    vencedor_nome     NVARCHAR(200)  NULL,
    vencedor_cnpj     CHAR(14)       NULL,
    created_at        DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at        DATETIME2      NULL,
    UNIQUE (numero, ano),
    FOREIGN KEY (secretaria_id) REFERENCES secretaria(id)
);
CREATE INDEX ix_licitacao_status ON licitacao(status);
CREATE INDEX ix_licitacao_ano    ON licitacao(ano);

CREATE TABLE licitacao_documento (
    id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    licitacao_id  BIGINT         NOT NULL,
    tipo          NVARCHAR(50)   NOT NULL, -- EDITAL, ATA, RESULTADO, PROPOSTA
    titulo        NVARCHAR(200)  NOT NULL,
    arquivo_id    BIGINT         NOT NULL,
    data          DATE           NULL,
    created_at    DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (licitacao_id) REFERENCES licitacao(id) ON DELETE CASCADE,
    FOREIGN KEY (arquivo_id)   REFERENCES arquivo(id)
);

CREATE TABLE contrato (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    numero          NVARCHAR(50)   NOT NULL,
    ano             INT            NOT NULL,
    licitacao_id    BIGINT         NULL,
    objeto          NVARCHAR(MAX)  NOT NULL,
    contratada      NVARCHAR(300)  NOT NULL,
    cnpj_contratada CHAR(14)       NULL,
    valor           DECIMAL(18,2)  NOT NULL,
    data_assinatura DATE           NOT NULL,
    vigencia_inicio DATE           NOT NULL,
    vigencia_fim    DATE           NULL,
    status          NVARCHAR(30)   NOT NULL DEFAULT 'VIGENTE',
    orgao           NVARCHAR(200)  NULL,
    arquivo_id      BIGINT         NULL,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at      DATETIME2      NULL,
    UNIQUE (numero, ano),
    FOREIGN KEY (licitacao_id) REFERENCES licitacao(id),
    FOREIGN KEY (arquivo_id)   REFERENCES arquivo(id)
);

CREATE TABLE convenio (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    numero          NVARCHAR(50)   NOT NULL,
    ano             INT            NOT NULL,
    objeto          NVARCHAR(MAX)  NOT NULL,
    concedente      NVARCHAR(300)  NOT NULL, -- órgão repassador (ex: União)
    proponente      NVARCHAR(300)  NOT NULL, -- prefeitura / secretaria
    valor_total     DECIMAL(18,2)  NOT NULL,
    valor_repasse   DECIMAL(18,2)  NULL,
    valor_contrapartida DECIMAL(18,2) NULL,
    inicio          DATE           NOT NULL,
    fim             DATE           NULL,
    status          NVARCHAR(30)   NOT NULL DEFAULT 'VIGENTE',
    arquivo_id      BIGINT         NULL,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (arquivo_id) REFERENCES arquivo(id),
    UNIQUE (numero, ano)
);

CREATE TABLE servidor (
    id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    matricula      NVARCHAR(30)   NOT NULL UNIQUE,
    nome           NVARCHAR(200)  NOT NULL,
    cpf            CHAR(11)       NULL,
    cargo          NVARCHAR(200)  NOT NULL,
    lotacao        NVARCHAR(200)  NULL,
    secretaria_id  BIGINT         NULL,
    tipo_vinculo   NVARCHAR(40)   NOT NULL, -- EFETIVO, COMISSIONADO, TEMPORARIO, ESTAGIARIO
    data_admissao  DATE           NULL,
    data_exoneracao DATE          NULL,
    situacao       NVARCHAR(30)   NOT NULL DEFAULT 'ATIVO', -- ATIVO, INATIVO, AFASTADO, APOSENTADO
    created_at     DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at     DATETIME2      NULL,
    FOREIGN KEY (secretaria_id) REFERENCES secretaria(id)
);
CREATE INDEX ix_servidor_cargo    ON servidor(cargo);
CREATE INDEX ix_servidor_situacao ON servidor(situacao);

CREATE TABLE folha_pagamento (
    id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    servidor_id      BIGINT         NOT NULL,
    competencia      CHAR(7)        NOT NULL, -- YYYY-MM
    salario_base     DECIMAL(18,2)  NOT NULL,
    gratificacoes    DECIMAL(18,2)  NOT NULL DEFAULT 0,
    descontos        DECIMAL(18,2)  NOT NULL DEFAULT 0,
    salario_bruto    DECIMAL(18,2)  NOT NULL,
    salario_liquido  DECIMAL(18,2)  NOT NULL,
    publicada        BIT            NOT NULL DEFAULT 0,
    created_at       DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    UNIQUE (servidor_id, competencia),
    FOREIGN KEY (servidor_id) REFERENCES servidor(id)
);
CREATE INDEX ix_folha_competencia ON folha_pagamento(competencia);

CREATE TABLE diaria (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    servidor_id BIGINT         NOT NULL,
    destino     NVARCHAR(200)  NOT NULL,
    motivo      NVARCHAR(MAX)  NOT NULL,
    data_ida    DATE           NOT NULL,
    data_volta  DATE           NOT NULL,
    valor       DECIMAL(18,2)  NOT NULL,
    portaria    NVARCHAR(50)   NULL,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (servidor_id) REFERENCES servidor(id)
);

CREATE TABLE obra (
    id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome           NVARCHAR(300)  NOT NULL,
    descricao      NVARCHAR(MAX)  NULL,
    endereco       NVARCHAR(255)  NULL,
    contrato_id    BIGINT         NULL,
    valor_previsto DECIMAL(18,2)  NOT NULL,
    valor_executado DECIMAL(18,2) NOT NULL DEFAULT 0,
    percentual     DECIMAL(5,2)   NOT NULL DEFAULT 0,
    inicio         DATE           NULL,
    previsao_fim   DATE           NULL,
    conclusao      DATE           NULL,
    status         NVARCHAR(30)   NOT NULL DEFAULT 'EM_ANDAMENTO', -- PLANEJADA, EM_ANDAMENTO, PARALISADA, CONCLUIDA, CANCELADA
    latitude       DECIMAL(10,7)  NULL,
    longitude      DECIMAL(10,7)  NULL,
    created_at     DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at     DATETIME2      NULL,
    FOREIGN KEY (contrato_id) REFERENCES contrato(id)
);

CREATE TABLE veiculo (
    id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    placa         NVARCHAR(10)   NOT NULL UNIQUE,
    modelo        NVARCHAR(100)  NOT NULL,
    marca         NVARCHAR(60)   NOT NULL,
    ano_fabricacao INT           NULL,
    ano_modelo    INT            NULL,
    tipo          NVARCHAR(40)   NULL, -- CARRO, MOTO, ONIBUS, CAMINHAO, MAQUINA
    secretaria_id BIGINT         NULL,
    situacao      NVARCHAR(30)   NOT NULL DEFAULT 'ATIVO',
    observacao    NVARCHAR(500)  NULL,
    created_at    DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (secretaria_id) REFERENCES secretaria(id)
);

/* =============================================================================
   6. E-SIC (Lei de Acesso à Informação)
============================================================================= */

CREATE TABLE esic_pedido (
    id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    protocolo     NVARCHAR(30)   NOT NULL UNIQUE,
    solicitante_id BIGINT        NULL,
    nome          NVARCHAR(200)  NOT NULL,
    email         NVARCHAR(255)  NOT NULL,
    cpf           CHAR(11)       NULL,
    telefone      NVARCHAR(20)   NULL,
    forma_recebimento NVARCHAR(30) NOT NULL, -- EMAIL, CORREIO, PRESENCIAL
    assunto       NVARCHAR(200)  NOT NULL,
    descricao     NVARCHAR(MAX)  NOT NULL,
    secretaria_id BIGINT         NULL,
    data_abertura DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    prazo         DATE           NOT NULL,
    status        NVARCHAR(30)   NOT NULL DEFAULT 'ABERTO', -- ABERTO, EM_ANALISE, RESPONDIDO, RECURSO, NEGADO, CANCELADO
    anonimo       BIT            NOT NULL DEFAULT 0,
    created_at    DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at    DATETIME2      NULL,
    FOREIGN KEY (solicitante_id) REFERENCES usuario(id),
    FOREIGN KEY (secretaria_id)  REFERENCES secretaria(id)
);
CREATE INDEX ix_esic_pedido_status ON esic_pedido(status);
CREATE INDEX ix_esic_pedido_cpf    ON esic_pedido(cpf);

CREATE TABLE esic_pedido_anexo (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    pedido_id  BIGINT NOT NULL,
    arquivo_id BIGINT NOT NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (pedido_id)  REFERENCES esic_pedido(id) ON DELETE CASCADE,
    FOREIGN KEY (arquivo_id) REFERENCES arquivo(id)
);

CREATE TABLE esic_resposta (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    pedido_id       BIGINT         NOT NULL,
    resposta        NVARCHAR(MAX)  NOT NULL,
    respondido_por  BIGINT         NOT NULL,
    respondido_em   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    arquivo_id      BIGINT         NULL,
    FOREIGN KEY (pedido_id)      REFERENCES esic_pedido(id) ON DELETE CASCADE,
    FOREIGN KEY (respondido_por) REFERENCES usuario(id),
    FOREIGN KEY (arquivo_id)     REFERENCES arquivo(id)
);

CREATE TABLE esic_recurso (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    pedido_id    BIGINT         NOT NULL,
    instancia    TINYINT        NOT NULL, -- 1, 2, 3 (CGU)
    justificativa NVARCHAR(MAX) NOT NULL,
    data_abertura DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    status        NVARCHAR(30)  NOT NULL DEFAULT 'ABERTO',
    resposta      NVARCHAR(MAX) NULL,
    respondido_em DATETIME2     NULL,
    FOREIGN KEY (pedido_id) REFERENCES esic_pedido(id)
);

/* =============================================================================
   7. OUVIDORIA
============================================================================= */

CREATE TABLE tipo_manifestacao (
    id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    codigo    NVARCHAR(30)  NOT NULL UNIQUE, -- RECLAMACAO, DENUNCIA, SUGESTAO, ELOGIO, SOLICITACAO
    nome      NVARCHAR(60)  NOT NULL,
    descricao NVARCHAR(300) NULL,
    prazo_dias INT          NOT NULL DEFAULT 30,
    ativo     BIT           NOT NULL DEFAULT 1
);

CREATE TABLE manifestacao (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    protocolo       NVARCHAR(30)   NOT NULL UNIQUE,
    tipo_id         BIGINT         NOT NULL,
    assunto         NVARCHAR(200)  NOT NULL,
    descricao       NVARCHAR(MAX)  NOT NULL,
    solicitante_id  BIGINT         NULL,
    nome            NVARCHAR(200)  NULL,
    email           NVARCHAR(255)  NULL,
    cpf             CHAR(11)       NULL,
    telefone        NVARCHAR(20)   NULL,
    anonima         BIT            NOT NULL DEFAULT 0,
    sigilo          BIT            NOT NULL DEFAULT 0,
    secretaria_id   BIGINT         NULL,
    status          NVARCHAR(30)   NOT NULL DEFAULT 'ABERTA', -- ABERTA, EM_ANALISE, RESPONDIDA, ENCERRADA
    data_abertura   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    prazo           DATE           NOT NULL,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at      DATETIME2      NULL,
    FOREIGN KEY (tipo_id)        REFERENCES tipo_manifestacao(id),
    FOREIGN KEY (solicitante_id) REFERENCES usuario(id),
    FOREIGN KEY (secretaria_id)  REFERENCES secretaria(id)
);
CREATE INDEX ix_manifestacao_status ON manifestacao(status);

CREATE TABLE manifestacao_anexo (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    manifestacao_id BIGINT NOT NULL,
    arquivo_id      BIGINT NOT NULL,
    created_at      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (manifestacao_id) REFERENCES manifestacao(id) ON DELETE CASCADE,
    FOREIGN KEY (arquivo_id)      REFERENCES arquivo(id)
);

CREATE TABLE manifestacao_resposta (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    manifestacao_id BIGINT         NOT NULL,
    resposta        NVARCHAR(MAX)  NOT NULL,
    respondido_por  BIGINT         NOT NULL,
    respondido_em   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    encerra         BIT            NOT NULL DEFAULT 0,
    FOREIGN KEY (manifestacao_id) REFERENCES manifestacao(id) ON DELETE CASCADE,
    FOREIGN KEY (respondido_por) REFERENCES usuario(id)
);

/* =============================================================================
   8. CARTA DE SERVIÇOS
============================================================================= */

CREATE TABLE categoria_servico (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome       NVARCHAR(150) NOT NULL UNIQUE,
    slug       NVARCHAR(150) NOT NULL UNIQUE,
    descricao  NVARCHAR(500) NULL,
    icone      NVARCHAR(60)  NULL,
    ordem      INT           NOT NULL DEFAULT 0,
    ativo      BIT           NOT NULL DEFAULT 1,
    created_at DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE servico (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    categoria_id    BIGINT         NOT NULL,
    secretaria_id   BIGINT         NULL,
    nome            NVARCHAR(200)  NOT NULL,
    slug            NVARCHAR(200)  NOT NULL UNIQUE,
    descricao       NVARCHAR(MAX)  NOT NULL,
    publico_alvo    NVARCHAR(500)  NULL,
    requisitos      NVARCHAR(MAX)  NULL,
    etapas          NVARCHAR(MAX)  NULL,  -- JSON com array de etapas
    prazo           NVARCHAR(100)  NULL,
    custo           NVARCHAR(200)  NULL,
    canais          NVARCHAR(500)  NULL,  -- online, presencial, telefone
    link_externo    NVARCHAR(500)  NULL,  -- link para sistema externo
    online          BIT            NOT NULL DEFAULT 0,
    destaque        BIT            NOT NULL DEFAULT 0,
    ativo           BIT            NOT NULL DEFAULT 1,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at      DATETIME2      NULL,
    FOREIGN KEY (categoria_id)  REFERENCES categoria_servico(id),
    FOREIGN KEY (secretaria_id) REFERENCES secretaria(id)
);
CREATE INDEX ix_servico_categoria ON servico(categoria_id);

CREATE TABLE servico_documento (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    servico_id BIGINT         NOT NULL,
    titulo     NVARCHAR(200)  NOT NULL,
    descricao  NVARCHAR(500)  NULL,
    obrigatorio BIT           NOT NULL DEFAULT 1,
    ordem      INT            NOT NULL DEFAULT 0,
    FOREIGN KEY (servico_id) REFERENCES servico(id) ON DELETE CASCADE
);

/* =============================================================================
   9. TRIBUTOS (IPTU / ISS / Taxa / NFS-e / Certidão)
============================================================================= */

CREATE TABLE iptu_imovel (
    id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    inscricao     NVARCHAR(30)   NOT NULL UNIQUE,
    contribuinte  NVARCHAR(200)  NOT NULL,
    cpf_cnpj      NVARCHAR(14)   NULL,
    endereco      NVARCHAR(255)  NOT NULL,
    cep           CHAR(8)        NULL,
    bairro        NVARCHAR(100)  NULL,
    area_terreno  DECIMAL(10,2)  NULL,
    area_construida DECIMAL(10,2) NULL,
    valor_venal   DECIMAL(18,2)  NULL,
    created_at    DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at    DATETIME2      NULL
);
CREATE INDEX ix_iptu_imovel_cpf ON iptu_imovel(cpf_cnpj);

CREATE TABLE iptu_lancamento (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    imovel_id   BIGINT         NOT NULL,
    exercicio   INT            NOT NULL,
    parcela     TINYINT        NOT NULL,
    valor       DECIMAL(18,2)  NOT NULL,
    vencimento  DATE           NOT NULL,
    status      NVARCHAR(20)   NOT NULL DEFAULT 'ABERTO', -- ABERTO, PAGO, VENCIDO, CANCELADO
    pago_em     DATETIME2      NULL,
    valor_pago  DECIMAL(18,2)  NULL,
    linha_digitavel NVARCHAR(100) NULL,
    qr_code_pix NVARCHAR(MAX)  NULL,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    UNIQUE (imovel_id, exercicio, parcela),
    FOREIGN KEY (imovel_id) REFERENCES iptu_imovel(id)
);
CREATE INDEX ix_iptu_lancamento_status ON iptu_lancamento(status);

CREATE TABLE iss_empresa (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    cnpj         CHAR(14)       NOT NULL UNIQUE,
    razao_social NVARCHAR(300)  NOT NULL,
    fantasia     NVARCHAR(200)  NULL,
    endereco     NVARCHAR(255)  NULL,
    atividade    NVARCHAR(200)  NULL,
    cnae         NVARCHAR(10)   NULL,
    inscricao_municipal NVARCHAR(30) NULL UNIQUE,
    situacao     NVARCHAR(20)   NOT NULL DEFAULT 'ATIVA',
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at   DATETIME2      NULL
);

CREATE TABLE iss_lancamento (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    empresa_id  BIGINT         NOT NULL,
    competencia CHAR(7)        NOT NULL, -- YYYY-MM
    valor       DECIMAL(18,2)  NOT NULL,
    vencimento  DATE           NOT NULL,
    status      NVARCHAR(20)   NOT NULL DEFAULT 'ABERTO',
    pago_em     DATETIME2      NULL,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    UNIQUE (empresa_id, competencia),
    FOREIGN KEY (empresa_id) REFERENCES iss_empresa(id)
);

CREATE TABLE taxa (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    codigo     NVARCHAR(30)   NOT NULL UNIQUE,
    nome       NVARCHAR(200)  NOT NULL,
    descricao  NVARCHAR(500)  NULL,
    valor_base DECIMAL(18,2)  NOT NULL,
    ativa      BIT            NOT NULL DEFAULT 1,
    created_at DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE taxa_lancamento (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    taxa_id      BIGINT         NOT NULL,
    contribuinte NVARCHAR(200)  NOT NULL,
    cpf_cnpj     NVARCHAR(14)   NULL,
    valor        DECIMAL(18,2)  NOT NULL,
    vencimento   DATE           NOT NULL,
    status       NVARCHAR(20)   NOT NULL DEFAULT 'ABERTO',
    pago_em      DATETIME2      NULL,
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (taxa_id) REFERENCES taxa(id)
);

CREATE TABLE nfse (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    numero          NVARCHAR(30)   NOT NULL,
    serie           NVARCHAR(10)   NULL,
    prestador_id    BIGINT         NOT NULL,
    tomador_nome    NVARCHAR(300)  NOT NULL,
    tomador_cpf_cnpj NVARCHAR(14)  NULL,
    tomador_email   NVARCHAR(255)  NULL,
    servico_descricao NVARCHAR(MAX) NOT NULL,
    cnae            NVARCHAR(10)   NULL,
    valor_servico   DECIMAL(18,2)  NOT NULL,
    valor_iss       DECIMAL(18,2)  NOT NULL,
    aliquota        DECIMAL(5,2)   NOT NULL,
    data_emissao    DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    data_competencia DATE          NOT NULL,
    codigo_verificacao NVARCHAR(30) NOT NULL UNIQUE,
    xml             NVARCHAR(MAX)  NULL,
    pdf_arquivo_id  BIGINT         NULL,
    cancelada       BIT            NOT NULL DEFAULT 0,
    cancelada_em    DATETIME2      NULL,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    UNIQUE (numero, serie),
    FOREIGN KEY (prestador_id)   REFERENCES iss_empresa(id),
    FOREIGN KEY (pdf_arquivo_id) REFERENCES arquivo(id)
);
CREATE INDEX ix_nfse_tomador ON nfse(tomador_cpf_cnpj);

CREATE TABLE certidao_solicitacao (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    protocolo    NVARCHAR(30)  NOT NULL UNIQUE,
    tipo         NVARCHAR(60)  NOT NULL, -- NEGATIVA_DEBITO, VALOR_VENAL, IMOVEL, TRIBUTARIA
    solicitante_id BIGINT      NULL,
    nome         NVARCHAR(200) NOT NULL,
    cpf_cnpj     NVARCHAR(14)  NOT NULL,
    email        NVARCHAR(255) NOT NULL,
    finalidade   NVARCHAR(300) NULL,
    status       NVARCHAR(20)  NOT NULL DEFAULT 'PENDENTE',
    arquivo_id   BIGINT        NULL,
    valida_ate   DATE          NULL,
    created_at   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (solicitante_id) REFERENCES usuario(id),
    FOREIGN KEY (arquivo_id)     REFERENCES arquivo(id)
);

/* =============================================================================
   10. AGENDAMENTO
============================================================================= */

CREATE TABLE agendamento_servico (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    servico_id      BIGINT         NOT NULL,
    secretaria_id   BIGINT         NOT NULL,
    nome            NVARCHAR(150)  NOT NULL,
    descricao       NVARCHAR(500)  NULL,
    duracao_minutos INT            NOT NULL DEFAULT 30,
    ativo           BIT            NOT NULL DEFAULT 1,
    FOREIGN KEY (servico_id)    REFERENCES servico(id),
    FOREIGN KEY (secretaria_id) REFERENCES secretaria(id)
);

CREATE TABLE horario_disponivel (
    id                     BIGINT IDENTITY(1,1) PRIMARY KEY,
    agendamento_servico_id BIGINT     NOT NULL,
    data                   DATE       NOT NULL,
    hora_inicio            TIME       NOT NULL,
    hora_fim               TIME       NOT NULL,
    vagas_total            INT        NOT NULL DEFAULT 1,
    vagas_ocupadas         INT        NOT NULL DEFAULT 0,
    ativo                  BIT        NOT NULL DEFAULT 1,
    FOREIGN KEY (agendamento_servico_id) REFERENCES agendamento_servico(id)
);
CREATE INDEX ix_horario_data ON horario_disponivel(data);

CREATE TABLE reserva_agendamento (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    horario_id   BIGINT        NOT NULL,
    protocolo    NVARCHAR(30)  NOT NULL UNIQUE,
    cidadao_id   BIGINT        NULL,
    nome         NVARCHAR(200) NOT NULL,
    cpf          CHAR(11)      NOT NULL,
    email        NVARCHAR(255) NOT NULL,
    telefone     NVARCHAR(20)  NULL,
    observacao   NVARCHAR(500) NULL,
    status       NVARCHAR(20)  NOT NULL DEFAULT 'CONFIRMADO', -- CONFIRMADO, CANCELADO, COMPARECEU, FALTOU
    cancelado_em DATETIME2     NULL,
    created_at   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (horario_id) REFERENCES horario_disponivel(id),
    FOREIGN KEY (cidadao_id) REFERENCES usuario(id)
);

/* =============================================================================
   11. PROTOCOLO
============================================================================= */

CREATE TABLE processo (
    id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    numero         NVARCHAR(30)   NOT NULL UNIQUE,
    assunto        NVARCHAR(200)  NOT NULL,
    descricao      NVARCHAR(MAX)  NULL,
    requerente_id  BIGINT         NULL,
    requerente_nome NVARCHAR(200) NOT NULL,
    requerente_cpf_cnpj NVARCHAR(14) NULL,
    secretaria_origem_id BIGINT   NULL,
    secretaria_atual_id  BIGINT   NULL,
    data_abertura  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    data_encerramento DATETIME2   NULL,
    status         NVARCHAR(30)   NOT NULL DEFAULT 'EM_TRAMITE', -- EM_TRAMITE, DEFERIDO, INDEFERIDO, ARQUIVADO
    sigiloso       BIT            NOT NULL DEFAULT 0,
    prioridade     NVARCHAR(20)   NOT NULL DEFAULT 'NORMAL', -- NORMAL, URGENTE
    created_at     DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at     DATETIME2      NULL,
    FOREIGN KEY (requerente_id)       REFERENCES usuario(id),
    FOREIGN KEY (secretaria_origem_id) REFERENCES secretaria(id),
    FOREIGN KEY (secretaria_atual_id)  REFERENCES secretaria(id)
);
CREATE INDEX ix_processo_status ON processo(status);

CREATE TABLE processo_documento (
    id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    processo_id   BIGINT        NOT NULL,
    arquivo_id    BIGINT        NOT NULL,
    descricao     NVARCHAR(200) NULL,
    enviado_por   BIGINT        NULL,
    created_at    DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (processo_id) REFERENCES processo(id) ON DELETE CASCADE,
    FOREIGN KEY (arquivo_id)  REFERENCES arquivo(id),
    FOREIGN KEY (enviado_por) REFERENCES usuario(id)
);

CREATE TABLE processo_tramitacao (
    id                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    processo_id         BIGINT         NOT NULL,
    de_secretaria_id    BIGINT         NULL,
    para_secretaria_id  BIGINT         NOT NULL,
    despacho            NVARCHAR(MAX)  NULL,
    usuario_id          BIGINT         NOT NULL,
    created_at          DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (processo_id)        REFERENCES processo(id) ON DELETE CASCADE,
    FOREIGN KEY (de_secretaria_id)   REFERENCES secretaria(id),
    FOREIGN KEY (para_secretaria_id) REFERENCES secretaria(id),
    FOREIGN KEY (usuario_id)         REFERENCES usuario(id)
);

/* =============================================================================
   12. COMUNICAÇÃO (Notícias, Eventos, Banners, Galeria, Agenda)
============================================================================= */

CREATE TABLE categoria_noticia (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome       NVARCHAR(100)  NOT NULL UNIQUE,
    slug       NVARCHAR(100)  NOT NULL UNIQUE,
    cor        NVARCHAR(20)   NULL,
    ordem      INT            NOT NULL DEFAULT 0,
    ativo      BIT            NOT NULL DEFAULT 1,
    created_at DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE tag (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome       NVARCHAR(60)  NOT NULL UNIQUE,
    slug       NVARCHAR(60)  NOT NULL UNIQUE,
    created_at DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE noticia (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    titulo          NVARCHAR(300)  NOT NULL,
    slug            NVARCHAR(300)  NOT NULL UNIQUE,
    resumo          NVARCHAR(500)  NULL,
    conteudo        NVARCHAR(MAX)  NOT NULL,
    autor_id        BIGINT         NULL,
    categoria_id    BIGINT         NULL,
    imagem_capa_id  BIGINT         NULL,
    destaque        BIT            NOT NULL DEFAULT 0,
    publicado_em    DATETIME2      NULL,
    status          NVARCHAR(20)   NOT NULL DEFAULT 'RASCUNHO', -- RASCUNHO, PUBLICADO, ARQUIVADO
    visualizacoes   INT            NOT NULL DEFAULT 0,
    meta_title      NVARCHAR(200)  NULL,
    meta_description NVARCHAR(300) NULL,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at      DATETIME2      NULL,
    deleted_at      DATETIME2      NULL,
    FOREIGN KEY (autor_id)       REFERENCES usuario(id),
    FOREIGN KEY (categoria_id)   REFERENCES categoria_noticia(id),
    FOREIGN KEY (imagem_capa_id) REFERENCES arquivo(id)
);
CREATE INDEX ix_noticia_publicado ON noticia(publicado_em DESC);
CREATE INDEX ix_noticia_status    ON noticia(status);

CREATE TABLE noticia_tag (
    noticia_id BIGINT NOT NULL,
    tag_id     BIGINT NOT NULL,
    PRIMARY KEY (noticia_id, tag_id),
    FOREIGN KEY (noticia_id) REFERENCES noticia(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)     REFERENCES tag(id)
);

CREATE TABLE noticia_imagem (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    noticia_id BIGINT NOT NULL,
    arquivo_id BIGINT NOT NULL,
    legenda    NVARCHAR(300) NULL,
    ordem      INT NOT NULL DEFAULT 0,
    FOREIGN KEY (noticia_id) REFERENCES noticia(id) ON DELETE CASCADE,
    FOREIGN KEY (arquivo_id) REFERENCES arquivo(id)
);

CREATE TABLE evento (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    titulo       NVARCHAR(200)  NOT NULL,
    slug         NVARCHAR(200)  NOT NULL UNIQUE,
    descricao    NVARCHAR(MAX)  NULL,
    data_inicio  DATETIME2      NOT NULL,
    data_fim     DATETIME2      NULL,
    local        NVARCHAR(255)  NULL,
    endereco     NVARCHAR(255)  NULL,
    latitude     DECIMAL(10,7)  NULL,
    longitude    DECIMAL(10,7)  NULL,
    publico      BIT            NOT NULL DEFAULT 1,
    gratuito     BIT            NOT NULL DEFAULT 1,
    valor        DECIMAL(18,2)  NULL,
    imagem_id    BIGINT         NULL,
    link_externo NVARCHAR(500)  NULL,
    destaque     BIT            NOT NULL DEFAULT 0,
    status       NVARCHAR(20)   NOT NULL DEFAULT 'PUBLICADO',
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at   DATETIME2      NULL,
    FOREIGN KEY (imagem_id) REFERENCES arquivo(id)
);
CREATE INDEX ix_evento_data ON evento(data_inicio);

CREATE TABLE banner (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    titulo      NVARCHAR(200)  NOT NULL,
    subtitulo   NVARCHAR(300)  NULL,
    imagem_id   BIGINT         NOT NULL,
    imagem_mobile_id BIGINT    NULL,
    link        NVARCHAR(500)  NULL,
    abre_nova_aba BIT          NOT NULL DEFAULT 0,
    ordem       INT            NOT NULL DEFAULT 0,
    ativo       BIT            NOT NULL DEFAULT 1,
    exibir_de   DATETIME2      NULL,
    exibir_ate  DATETIME2      NULL,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (imagem_id)        REFERENCES arquivo(id),
    FOREIGN KEY (imagem_mobile_id) REFERENCES arquivo(id)
);

CREATE TABLE galeria (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    titulo      NVARCHAR(200)  NOT NULL,
    slug        NVARCHAR(200)  NOT NULL UNIQUE,
    descricao   NVARCHAR(500)  NULL,
    data        DATE           NULL,
    capa_id     BIGINT         NULL,
    publicada   BIT            NOT NULL DEFAULT 1,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (capa_id) REFERENCES arquivo(id)
);

CREATE TABLE galeria_item (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    galeria_id BIGINT         NOT NULL,
    tipo       NVARCHAR(10)   NOT NULL DEFAULT 'IMAGEM', -- IMAGEM, VIDEO
    arquivo_id BIGINT         NULL,
    url_video  NVARCHAR(500)  NULL,
    legenda    NVARCHAR(300)  NULL,
    ordem      INT            NOT NULL DEFAULT 0,
    FOREIGN KEY (galeria_id) REFERENCES galeria(id) ON DELETE CASCADE,
    FOREIGN KEY (arquivo_id) REFERENCES arquivo(id)
);

CREATE TABLE agenda_prefeito (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    titulo      NVARCHAR(200)  NOT NULL,
    descricao   NVARCHAR(MAX)  NULL,
    data        DATE           NOT NULL,
    hora_inicio TIME           NULL,
    hora_fim    TIME           NULL,
    local       NVARCHAR(255)  NULL,
    publico     BIT            NOT NULL DEFAULT 1,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
CREATE INDEX ix_agenda_data ON agenda_prefeito(data);

/* =============================================================================
   13. DIÁRIO OFICIAL
============================================================================= */

CREATE TABLE edicao_diario (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    numero       INT           NOT NULL,
    ano          INT           NOT NULL,
    data         DATE          NOT NULL,
    arquivo_id   BIGINT        NULL,
    assinado_por NVARCHAR(200) NULL,
    status       NVARCHAR(20)  NOT NULL DEFAULT 'PUBLICADO', -- RASCUNHO, PUBLICADO, REVOGADO
    hash_arquivo CHAR(64)      NULL,
    created_at   DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    UNIQUE (numero, ano),
    FOREIGN KEY (arquivo_id) REFERENCES arquivo(id)
);
CREATE INDEX ix_edicao_data ON edicao_diario(data DESC);

CREATE TABLE materia_diario (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    edicao_id  BIGINT         NOT NULL,
    tipo       NVARCHAR(40)   NOT NULL, -- DECRETO, PORTARIA, LEI, EDITAL, ATA, RESOLUCAO
    numero     NVARCHAR(40)   NULL,
    titulo     NVARCHAR(300)  NOT NULL,
    conteudo   NVARCHAR(MAX)  NOT NULL,
    pagina     INT            NULL,
    created_at DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (edicao_id) REFERENCES edicao_diario(id) ON DELETE CASCADE
);
CREATE INDEX ix_materia_tipo ON materia_diario(tipo);

/* =============================================================================
   14. CONCURSOS PÚBLICOS
============================================================================= */

CREATE TABLE edital_concurso (
    id                BIGINT IDENTITY(1,1) PRIMARY KEY,
    numero            NVARCHAR(30)   NOT NULL,
    ano               INT            NOT NULL,
    titulo            NVARCHAR(200)  NOT NULL,
    descricao         NVARCHAR(MAX)  NULL,
    orgao             NVARCHAR(200)  NULL,
    banca             NVARCHAR(200)  NULL,
    inscricao_inicio  DATE           NULL,
    inscricao_fim     DATE           NULL,
    valor_inscricao   DECIMAL(10,2)  NULL,
    prova_objetiva_data DATE         NULL,
    resultado_previsto DATE          NULL,
    status            NVARCHAR(30)   NOT NULL DEFAULT 'ABERTO', -- ABERTO, EM_ANDAMENTO, HOMOLOGADO, CANCELADO
    arquivo_edital_id BIGINT         NULL,
    created_at        DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    UNIQUE (numero, ano),
    FOREIGN KEY (arquivo_edital_id) REFERENCES arquivo(id)
);

CREATE TABLE cargo_concurso (
    id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    edital_id     BIGINT         NOT NULL,
    nome          NVARCHAR(200)  NOT NULL,
    escolaridade  NVARCHAR(60)   NULL,
    vagas         INT            NOT NULL,
    vagas_pcd     INT            NOT NULL DEFAULT 0,
    salario       DECIMAL(18,2)  NOT NULL,
    carga_horaria NVARCHAR(50)   NULL,
    requisitos    NVARCHAR(MAX)  NULL,
    FOREIGN KEY (edital_id) REFERENCES edital_concurso(id) ON DELETE CASCADE
);

CREATE TABLE concurso_documento (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    edital_id   BIGINT         NOT NULL,
    tipo        NVARCHAR(50)   NOT NULL, -- EDITAL, ERRATA, GABARITO, CONVOCACAO, RESULTADO, HOMOLOGACAO
    titulo      NVARCHAR(200)  NOT NULL,
    arquivo_id  BIGINT         NOT NULL,
    data        DATE           NULL,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (edital_id)  REFERENCES edital_concurso(id) ON DELETE CASCADE,
    FOREIGN KEY (arquivo_id) REFERENCES arquivo(id)
);

CREATE TABLE inscricao_concurso (
    id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    cargo_id      BIGINT         NOT NULL,
    candidato_id  BIGINT         NULL,
    protocolo     NVARCHAR(30)   NOT NULL UNIQUE,
    nome          NVARCHAR(200)  NOT NULL,
    cpf           CHAR(11)       NOT NULL,
    email         NVARCHAR(255)  NOT NULL,
    pcd           BIT            NOT NULL DEFAULT 0,
    pagamento_status NVARCHAR(20) NOT NULL DEFAULT 'PENDENTE',
    created_at    DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (cargo_id)     REFERENCES cargo_concurso(id),
    FOREIGN KEY (candidato_id) REFERENCES usuario(id),
    UNIQUE (cargo_id, cpf)
);

/* =============================================================================
   15. TURISMO / CULTURA
============================================================================= */

CREATE TABLE ponto_turistico (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome         NVARCHAR(200)  NOT NULL,
    slug         NVARCHAR(200)  NOT NULL UNIQUE,
    descricao    NVARCHAR(MAX)  NOT NULL,
    categoria    NVARCHAR(60)   NULL, -- NATUREZA, HISTORICO, RELIGIOSO, CULTURAL
    endereco     NVARCHAR(255)  NULL,
    horario      NVARCHAR(200)  NULL,
    telefone     NVARCHAR(20)   NULL,
    latitude     DECIMAL(10,7)  NULL,
    longitude    DECIMAL(10,7)  NULL,
    imagem_capa_id BIGINT       NULL,
    destaque     BIT            NOT NULL DEFAULT 0,
    ativo        BIT            NOT NULL DEFAULT 1,
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (imagem_capa_id) REFERENCES arquivo(id)
);

CREATE TABLE ponto_turistico_imagem (
    id                 BIGINT IDENTITY(1,1) PRIMARY KEY,
    ponto_turistico_id BIGINT NOT NULL,
    arquivo_id         BIGINT NOT NULL,
    legenda            NVARCHAR(300) NULL,
    ordem              INT NOT NULL DEFAULT 0,
    FOREIGN KEY (ponto_turistico_id) REFERENCES ponto_turistico(id) ON DELETE CASCADE,
    FOREIGN KEY (arquivo_id)         REFERENCES arquivo(id)
);

CREATE TABLE roteiro_turistico (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome       NVARCHAR(200)  NOT NULL,
    slug       NVARCHAR(200)  NOT NULL UNIQUE,
    descricao  NVARCHAR(MAX)  NULL,
    duracao    NVARCHAR(60)   NULL,
    dificuldade NVARCHAR(20)  NULL,
    imagem_id  BIGINT         NULL,
    created_at DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (imagem_id) REFERENCES arquivo(id)
);

CREATE TABLE roteiro_ponto (
    roteiro_id BIGINT NOT NULL,
    ponto_id   BIGINT NOT NULL,
    ordem      INT    NOT NULL,
    PRIMARY KEY (roteiro_id, ponto_id),
    FOREIGN KEY (roteiro_id) REFERENCES roteiro_turistico(id) ON DELETE CASCADE,
    FOREIGN KEY (ponto_id)   REFERENCES ponto_turistico(id)
);

CREATE TABLE patrimonio_cultural (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome         NVARCHAR(200)  NOT NULL,
    tipo         NVARCHAR(60)   NOT NULL, -- MATERIAL, IMATERIAL, NATURAL, ARQUEOLOGICO
    descricao    NVARCHAR(MAX)  NOT NULL,
    localizacao  NVARCHAR(255)  NULL,
    numero_registro NVARCHAR(50) NULL,
    orgao_registro NVARCHAR(100) NULL,
    data_registro DATE          NULL,
    imagem_id    BIGINT         NULL,
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (imagem_id) REFERENCES arquivo(id)
);

CREATE TABLE projeto_cultural (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome        NVARCHAR(200)  NOT NULL,
    descricao   NVARCHAR(MAX)  NOT NULL,
    proponente  NVARCHAR(200)  NULL,
    valor       DECIMAL(18,2)  NULL,
    inicio      DATE           NULL,
    fim         DATE           NULL,
    status      NVARCHAR(30)   NOT NULL DEFAULT 'EM_ANDAMENTO',
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);

/* =============================================================================
   16. LGPD
============================================================================= */

CREATE TABLE politica_privacidade (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    versao      NVARCHAR(20)   NOT NULL,
    conteudo    NVARCHAR(MAX)  NOT NULL,
    vigencia_de DATE           NOT NULL,
    vigencia_ate DATE          NULL,
    ativa       BIT            NOT NULL DEFAULT 0,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE dpo (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome       NVARCHAR(200) NOT NULL,
    email      NVARCHAR(255) NOT NULL,
    telefone   NVARCHAR(20)  NULL,
    cargo      NVARCHAR(100) NULL,
    posse_em   DATE          NOT NULL,
    fim_mandato DATE         NULL,
    ativo      BIT           NOT NULL DEFAULT 1,
    created_at DATETIME2     NOT NULL DEFAULT SYSDATETIME()
);

CREATE TABLE lgpd_solicitacao (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    protocolo    NVARCHAR(30)   NOT NULL UNIQUE,
    tipo         NVARCHAR(40)   NOT NULL, -- ACESSO, CORRECAO, EXCLUSAO, PORTABILIDADE, ANONIMIZACAO, REVOGACAO
    titular_id   BIGINT         NULL,
    titular_nome NVARCHAR(200)  NOT NULL,
    titular_cpf  CHAR(11)       NULL,
    titular_email NVARCHAR(255) NOT NULL,
    descricao    NVARCHAR(MAX)  NOT NULL,
    status       NVARCHAR(30)   NOT NULL DEFAULT 'ABERTA',
    resposta     NVARCHAR(MAX)  NULL,
    respondido_em DATETIME2     NULL,
    respondido_por BIGINT       NULL,
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    prazo        DATE           NOT NULL,
    FOREIGN KEY (titular_id)     REFERENCES usuario(id),
    FOREIGN KEY (respondido_por) REFERENCES usuario(id)
);

/* =============================================================================
   17. NEWSLETTER
============================================================================= */

CREATE TABLE newsletter_inscricao (
    id                BIGINT IDENTITY(1,1) PRIMARY KEY,
    email             NVARCHAR(255) NOT NULL UNIQUE,
    nome              NVARCHAR(200) NULL,
    ativo             BIT           NOT NULL DEFAULT 1,
    confirmado        BIT           NOT NULL DEFAULT 0,
    token_confirmacao NVARCHAR(100) NULL,
    token_descadastro NVARCHAR(100) NOT NULL,
    created_at        DATETIME2     NOT NULL DEFAULT SYSDATETIME(),
    descadastrado_em  DATETIME2     NULL
);

CREATE TABLE newsletter_envio (
    id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    assunto         NVARCHAR(200)  NOT NULL,
    conteudo        NVARCHAR(MAX)  NOT NULL,
    total_destinatarios INT        NOT NULL DEFAULT 0,
    total_enviados  INT            NOT NULL DEFAULT 0,
    total_erros     INT            NOT NULL DEFAULT 0,
    agendado_para   DATETIME2      NULL,
    enviado_em      DATETIME2      NULL,
    status          NVARCHAR(20)   NOT NULL DEFAULT 'RASCUNHO',
    created_by_id   BIGINT         NULL,
    created_at      DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (created_by_id) REFERENCES usuario(id)
);

/* =============================================================================
   18. CONTATO
============================================================================= */

CREATE TABLE contato_mensagem (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    nome       NVARCHAR(200)  NOT NULL,
    email      NVARCHAR(255)  NOT NULL,
    telefone   NVARCHAR(20)   NULL,
    assunto    NVARCHAR(200)  NOT NULL,
    mensagem   NVARCHAR(MAX)  NOT NULL,
    lido       BIT            NOT NULL DEFAULT 0,
    respondido BIT            NOT NULL DEFAULT 0,
    ip         NVARCHAR(45)   NULL,
    created_at DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    lido_em    DATETIME2      NULL
);
CREATE INDEX ix_contato_lido ON contato_mensagem(lido);

/* =============================================================================
   19. BUSCA (log para analytics)
============================================================================= */

CREATE TABLE busca_log (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    termo        NVARCHAR(300)  NOT NULL,
    usuario_id   BIGINT         NULL,
    total_resultados INT        NOT NULL DEFAULT 0,
    ip           NVARCHAR(45)   NULL,
    user_agent   NVARCHAR(500)  NULL,
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);
CREATE INDEX ix_busca_termo ON busca_log(termo);

/* =============================================================================
   20. NOTIFICAÇÕES (templates + logs)
============================================================================= */

CREATE TABLE notification_template (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    codigo     NVARCHAR(80)   NOT NULL UNIQUE, -- ex: ESIC_CONFIRMACAO, SENHA_RECUPERACAO
    canal      NVARCHAR(20)   NOT NULL, -- EMAIL, SMS, PUSH
    assunto    NVARCHAR(200)  NULL,
    corpo      NVARCHAR(MAX)  NOT NULL,
    variaveis  NVARCHAR(500)  NULL, -- lista de placeholders aceitos
    ativo      BIT            NOT NULL DEFAULT 1,
    created_at DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at DATETIME2      NULL
);

CREATE TABLE notification_log (
    id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    template_id  BIGINT         NULL,
    canal        NVARCHAR(20)   NOT NULL,
    destinatario NVARCHAR(255)  NOT NULL,
    assunto      NVARCHAR(200)  NULL,
    corpo        NVARCHAR(MAX)  NULL,
    status       NVARCHAR(20)   NOT NULL, -- ENVIADO, ERRO, PENDENTE
    erro         NVARCHAR(MAX)  NULL,
    enviado_em   DATETIME2      NULL,
    created_at   DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (template_id) REFERENCES notification_template(id)
);
CREATE INDEX ix_notification_status ON notification_log(status);

/* =============================================================================
   21. INTEGRAÇÕES EXTERNAS (logs)
============================================================================= */

CREATE TABLE integration_log (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    sistema     NVARCHAR(40)   NOT NULL, -- GOVBR, RECEITA_FEDERAL, SEFAZ, PIX, VLIBRAS, CERTIFICADO, DOE
    operacao    NVARCHAR(100)  NOT NULL,
    endpoint    NVARCHAR(500)  NULL,
    request_body NVARCHAR(MAX) NULL,
    response_body NVARCHAR(MAX) NULL,
    status_code INT            NULL,
    sucesso     BIT            NOT NULL DEFAULT 0,
    erro        NVARCHAR(MAX)  NULL,
    duracao_ms  INT            NULL,
    usuario_id  BIGINT         NULL,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    FOREIGN KEY (usuario_id) REFERENCES usuario(id)
);
CREATE INDEX ix_integration_sistema ON integration_log(sistema);
CREATE INDEX ix_integration_created ON integration_log(created_at);

/* =============================================================================
   22. CONFIGURAÇÕES GERAIS DO PORTAL
============================================================================= */

CREATE TABLE configuracao (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    chave       NVARCHAR(100)  NOT NULL UNIQUE,
    valor       NVARCHAR(MAX)  NULL,
    tipo        NVARCHAR(20)   NOT NULL DEFAULT 'STRING', -- STRING, INT, BOOL, JSON
    descricao   NVARCHAR(300)  NULL,
    categoria   NVARCHAR(60)   NULL, -- GERAL, EMAIL, SMTP, SEO, REDES_SOCIAIS
    editavel    BIT            NOT NULL DEFAULT 1,
    updated_at  DATETIME2      NULL
);

CREATE TABLE pagina_estatica (
    id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    slug        NVARCHAR(200)  NOT NULL UNIQUE,
    titulo      NVARCHAR(200)  NOT NULL,
    conteudo    NVARCHAR(MAX)  NOT NULL,
    meta_title  NVARCHAR(200)  NULL,
    meta_description NVARCHAR(300) NULL,
    publicada   BIT            NOT NULL DEFAULT 1,
    created_at  DATETIME2      NOT NULL DEFAULT SYSDATETIME(),
    updated_at  DATETIME2      NULL
);

CREATE TABLE redes_social (
    id         BIGINT IDENTITY(1,1) PRIMARY KEY,
    tipo       NVARCHAR(30)  NOT NULL, -- FACEBOOK, INSTAGRAM, TWITTER, YOUTUBE, TIKTOK, LINKEDIN
    url        NVARCHAR(500) NOT NULL,
    ordem      INT           NOT NULL DEFAULT 0,
    ativo      BIT           NOT NULL DEFAULT 1
);

GO

/* =============================================================================
   23. SEEDS INICIAIS MÍNIMAS
============================================================================= */

INSERT INTO papel (nome, descricao, sistema) VALUES
    ('ROLE_ADMIN',          'Administrador geral do portal', 1),
    ('ROLE_EDITOR',         'Edita conteúdo (notícias, eventos)', 1),
    ('ROLE_SECRETARIA',     'Servidor de secretaria', 1),
    ('ROLE_OUVIDOR',        'Responde ouvidoria e e-SIC', 1),
    ('ROLE_CIDADAO',        'Cidadão comum cadastrado', 1);

INSERT INTO tipo_manifestacao (codigo, nome, prazo_dias) VALUES
    ('RECLAMACAO',  'Reclamação',  30),
    ('DENUNCIA',    'Denúncia',    30),
    ('SUGESTAO',    'Sugestão',    30),
    ('ELOGIO',      'Elogio',      30),
    ('SOLICITACAO', 'Solicitação', 30);

INSERT INTO categoria_noticia (nome, slug, ordem) VALUES
    ('Geral',      'geral',      1),
    ('Saúde',      'saude',      2),
    ('Educação',   'educacao',   3),
    ('Obras',      'obras',      4),
    ('Cultura',    'cultura',    5),
    ('Esporte',    'esporte',    6),
    ('Turismo',    'turismo',    7),
    ('Assistência Social', 'assistencia-social', 8);

INSERT INTO categoria_servico (nome, slug, ordem) VALUES
    ('Saúde',             'saude',             1),
    ('Educação',          'educacao',          2),
    ('Tributos',          'tributos',          3),
    ('Obras e Habitação', 'obras-habitacao',   4),
    ('Assistência Social','assistencia-social',5),
    ('Meio Ambiente',     'meio-ambiente',     6),
    ('Cultura e Lazer',   'cultura-lazer',     7),
    ('Documentação',      'documentacao',      8);

INSERT INTO configuracao (chave, valor, tipo, categoria, descricao) VALUES
    ('portal.titulo',           'Prefeitura de Jardel Alves', 'STRING', 'GERAL', 'Título do portal'),
    ('portal.slogan',           'Trabalhando pelo nosso município', 'STRING', 'GERAL', 'Slogan'),
    ('portal.email_contato',    'contato@jardelalves.gov.br', 'STRING', 'EMAIL', 'E-mail de contato principal'),
    ('portal.telefone',         '(00) 0000-0000', 'STRING', 'GERAL', 'Telefone principal'),
    ('portal.horario',          'Segunda a Sexta, das 8h às 17h', 'STRING', 'GERAL', 'Horário de atendimento'),
    ('portal.vlibras.ativo',    'true', 'BOOL', 'ACESSIBILIDADE', 'Ativar widget VLibras');

GO

/* =============================================================================
   FIM
============================================================================= */
