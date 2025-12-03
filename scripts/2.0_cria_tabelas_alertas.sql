/*
    Objetivo: criar as tabelas, sequências e parâmetros de alerta para a solução de monitoria.
    Banco alvo: Oracle Database 12c ou superior.
    Pré‑requisitos: esquema de monitoria criado e privilégios adequados.
    Responsável: Adaptado do Script_SQLServer_Alerts (2.0 - Create Alert Table.sql).
    Histórico de versões:
      v1.0 - Criação inicial das tabelas e parâmetros.

    Este script cria:
      - Sequências para chave primária.
      - Tabelas de configuração (ALERTAS, PARAMETROS_ALERTA, ALERTAS_CUSTOMIZACAO).
      - Tabelas de log para diversos tipos de alerta (LOG_IO_PENDING, LOG_DEADLOCK, etc.).
      - Views de apoio (opcional).
      - Carga inicial de parâmetros com alertas padrão.

    Todos os objetos são criados no esquema atual (usuário conectado). Ajuste nomes de tablespace e quotas conforme necessário.
*/

-- Criar sequência genérica para IDs de alertas
CREATE SEQUENCE seq_alerta START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Tabela principal de alertas
CREATE TABLE alertas (
    id_alerta        NUMBER      PRIMARY KEY,
    nome_alerta      VARCHAR2(100) NOT NULL,
    descricao        VARCHAR2(4000),
    procedimento     VARCHAR2(200) NOT NULL,
    frequencia_min   NUMBER DEFAULT 5,
    ativo            CHAR(1) DEFAULT 'S' CHECK (ativo IN ('S','N')),
    data_criacao     DATE DEFAULT SYSDATE
);

-- Tabela de parâmetros de alerta (thresholds, destinatários, etc.)
CREATE TABLE parametros_alerta (
    id_parametro     NUMBER      PRIMARY KEY,
    nome_parametro   VARCHAR2(100) NOT NULL UNIQUE,
    valor            VARCHAR2(4000) NOT NULL,
    descricao        VARCHAR2(4000),
    data_criacao     DATE DEFAULT SYSDATE
);

CREATE SEQUENCE seq_parametro START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Tabela para customizações específicas de cada alerta
CREATE TABLE alertas_customizacao (
    id_customizacao  NUMBER PRIMARY KEY,
    id_alerta        NUMBER REFERENCES alertas(id_alerta),
    chave            VARCHAR2(100) NOT NULL,
    valor            VARCHAR2(4000) NOT NULL
);
CREATE SEQUENCE seq_customizacao START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

/*
   Tabelas de log: cada alerta poderá gravar informações específicas em sua própria tabela.
   Abaixo alguns exemplos baseados no repositório original. Outras tabelas podem ser criadas conforme necessidade.
*/

-- Log de IO pendente
CREATE TABLE log_io_pending (
    id_log          NUMBER PRIMARY KEY,
    data_evento     DATE      NOT NULL,
    tempo_espera_ms NUMBER,
    arquivo         VARCHAR2(400),
    motivo          VARCHAR2(4000)
);
CREATE SEQUENCE seq_log_io START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Log de deadlocks
CREATE TABLE log_deadlock (
    id_log          NUMBER PRIMARY KEY,
    data_evento     DATE      NOT NULL,
    sessao_1        VARCHAR2(100),
    sessao_2        VARCHAR2(100),
    objeto_conflito VARCHAR2(200),
    xml_evento      CLOB
);
CREATE SEQUENCE seq_log_deadlock START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Log de uso de tablespace (snapshot)
CREATE TABLE log_tablespace (
    id_log          NUMBER PRIMARY KEY,
    nome_tablespace VARCHAR2(30) NOT NULL,
    pct_utilizado   NUMBER(5,2),
    bytes_total     NUMBER,
    bytes_livres    NUMBER,
    data_coleta     DATE DEFAULT SYSDATE
);
CREATE SEQUENCE seq_log_ts START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Outras tabelas de log podem ser criadas de acordo com as monitorias implementadas: log_bloqueios, log_long_queries, log_fragmentacao_indice, etc.

/*
  Inserção de alertas padrão na tabela ALERTAS.
  Cada linha representa um tipo de alerta equivalente aos procedimentos do script original.
  Ajuste a lista conforme desejar. Adicione novos alertas criando novas linhas.
*/
INSERT INTO alertas (id_alerta, nome_alerta, descricao, procedimento, frequencia_min, ativo)
VALUES (seq_alerta.NEXTVAL, 'Espaço em Tablespace', 'Alerta para tablespaces que ultrapassam limite percentual de uso', 'pr_alerta_espaco_tbs', 30, 'S');

INSERT INTO alertas (id_alerta, nome_alerta, descricao, procedimento, frequencia_min, ativo)
VALUES (seq_alerta.NEXTVAL, 'Processo Bloqueado', 'Alerta quando há sessões bloqueadas além do tempo permitido', 'pr_alerta_processo_bloqueado', 5, 'S');

INSERT INTO alertas (id_alerta, nome_alerta, descricao, procedimento, frequencia_min, ativo)
VALUES (seq_alerta.NEXTVAL, 'Fragmentação de Índice', 'Detecta índices com alto nível de fragmentação', 'pr_alerta_fragmentacao_indice', 1440, 'S');

INSERT INTO alertas (id_alerta, nome_alerta, descricao, procedimento, frequencia_min, ativo)
VALUES (seq_alerta.NEXTVAL, 'Sessões de Longa Duração', 'Identifica queries rodando acima do tempo configurado', 'pr_alerta_sessoes_longas', 10, 'S');

INSERT INTO alertas (id_alerta, nome_alerta, descricao, procedimento, frequencia_min, ativo)
VALUES (seq_alerta.NEXTVAL, 'Deadlock', 'Monitora eventos de deadlock no banco', 'pr_alerta_deadlock', 5, 'S');

COMMIT;

/*
  Inserção de parâmetros padrão. Esses valores podem ser ajustados após instalação.
*/
INSERT INTO parametros_alerta (id_parametro, nome_parametro, valor, descricao)
VALUES (seq_parametro.NEXTVAL, 'LIMITE_TABLESPACE_PCT', '80', 'Percentual de utilização da tablespace para disparar alerta');

INSERT INTO parametros_alerta (id_parametro, nome_parametro, valor, descricao)
VALUES (seq_parametro.NEXTVAL, 'LIMITE_CPU_PCT', '90', 'Percentual de CPU que dispara alerta de alto consumo');

INSERT INTO parametros_alerta (id_parametro, nome_parametro, valor, descricao)
VALUES (seq_parametro.NEXTVAL, 'LIMITE_TEMPO_QUERY_MIN', '15', 'Tempo mínimo (minutos) para considerar query longa');

INSERT INTO parametros_alerta (id_parametro, nome_parametro, valor, descricao)
VALUES (seq_parametro.NEXTVAL, 'EMAIL_FROM', 'monitor@empresa.com', 'Remetente padrão para envio de alertas');

INSERT INTO parametros_alerta (id_parametro, nome_parametro, valor, descricao)
VALUES (seq_parametro.NEXTVAL, 'EMAIL_TO', 'dba@empresa.com', 'Destinatários separados por vírgula');

COMMIT;

/*
  Comentário final: adicione ou ajuste tabelas e parâmetros para refletir outros alertas presentes no projeto original,
  como monitoramento de logs, tempos de espera, crescimento de bases, falhas de backup, etc.
*/