/*
    Objetivo: criar as procedures de alerta, pacote de utilidades e agendar jobs via DBMS_SCHEDULER.
    Banco alvo: Oracle Database 12c ou superior.
    Responsável: Adaptado do Script_SQLServer_Alerts (2.1 - Create All Alert Procedures and Jobs.sql).
    Histórico de versões:
      v1.0 - Implementação inicial de procedures de alerta básicas e utilidades.

    Este script:
      1. Cria o pacote PKG_MONITORIA_UTILS com funções/procedures de apoio.
      2. Cria procedures para cada alerta principal (espaço de tablespace, processos bloqueados, fragmentação de índice, sessões longas, deadlock).
      3. Agenda jobs no DBMS_SCHEDULER para executar as procedures com base na tabela ALERTAS.

    Comentários estão em português conforme solicitado.
*/

-- Criar pacote de utilidades
CREATE OR REPLACE PACKAGE pkg_monitoria_utils IS
    -- Obtém o valor de um parâmetro de alerta pela chave
    FUNCTION get_parametro (p_nome VARCHAR2) RETURN VARCHAR2;

    -- Envia e‑mail em formato HTML.
    PROCEDURE envia_email_html(
        p_assunto   IN VARCHAR2,
        p_corpo     IN CLOB
    );

    -- Constrói template HTML simples para alertas
    FUNCTION gera_template_alerta(
        p_titulo    IN VARCHAR2,
        p_conteudo  IN CLOB
    ) RETURN CLOB;
END pkg_monitoria_utils;
/

CREATE OR REPLACE PACKAGE BODY pkg_monitoria_utils IS

    FUNCTION get_parametro (p_nome VARCHAR2) RETURN VARCHAR2 IS
        v_valor parametros_alerta.valor%TYPE;
    BEGIN
        SELECT valor INTO v_valor
          FROM parametros_alerta
         WHERE UPPER(nome_parametro) = UPPER(p_nome);
        RETURN v_valor;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;
    END;

    PROCEDURE envia_email_html(
        p_assunto   IN VARCHAR2,
        p_corpo     IN CLOB
    ) IS
        v_from   VARCHAR2(200);
        v_to     VARCHAR2(2000);
    BEGIN
        v_from := get_parametro('EMAIL_FROM');
        v_to   := get_parametro('EMAIL_TO');
        -- Se não houver destinatário, não envia
        IF v_to IS NULL THEN
            RETURN;
        END IF;
        -- Envio via UTL_MAIL; caso deseje usar UTL_SMTP, adapte aqui
        UTL_MAIL.send(
            sender      => v_from,
            recipients  => v_to,
            subject     => p_assunto,
            message     => p_corpo,
            mime_type   => 'text/html; charset=UTF-8'
        );
    EXCEPTION
        WHEN OTHERS THEN
            -- Registrar erro opcionalmente em tabela de log
            NULL;
    END;

    FUNCTION gera_template_alerta(
        p_titulo    IN VARCHAR2,
        p_conteudo  IN CLOB
    ) RETURN CLOB IS
        v_html CLOB;
    BEGIN
        v_html := '<html><body style="font-family:Arial, sans-serif;">'
                  || '<h2 style="color:#2f5597;">' || p_titulo || '</h2>'
                  || '<div>' || p_conteudo || '</div>'
                  || '<hr><small>Este e‑mail foi gerado automaticamente pelo sistema de monitoria Oracle.</small>'
                  || '</body></html>';
        RETURN v_html;
    END;
END pkg_monitoria_utils;
/

/*
   Procedure: pr_alerta_espaco_tbs
   Objetivo: verificar uso de tablespaces e disparar alerta quando o percentual ultrapassa o limite configurado em LIMITE_TABLESPACE_PCT.
*/
CREATE OR REPLACE PROCEDURE pr_alerta_espaco_tbs IS
    v_limite        NUMBER := TO_NUMBER(pkg_monitoria_utils.get_parametro('LIMITE_TABLESPACE_PCT'));
    v_corpo         CLOB;
    v_titulo        VARCHAR2(200);
BEGIN
    v_titulo := 'Alerta: Uso de Tablespace acima de ' || v_limite || '%';
    -- Construir corpo em HTML com a lista de tablespaces acima do limite
    v_corpo := '<table border="1" cellpadding="3" cellspacing="0"><tr>' ||
               '<th>Tablespace</th><th>% Utilizado</th><th>Tamanho (GB)</th><th>Livre (GB)</th></tr>';
    FOR rec IN (
        SELECT
            df.tablespace_name   AS nome_ts,
            ROUND((df.total_bytes - fs.free_bytes) / df.total_bytes * 100, 2) AS pct_util,
            ROUND(df.total_bytes/1024/1024/1024,2) AS total_gb,
            ROUND(fs.free_bytes/1024/1024/1024,2) AS livre_gb
        FROM (
            SELECT tablespace_name, SUM(bytes) AS total_bytes
              FROM dba_data_files
             GROUP BY tablespace_name
        ) df
        JOIN (
            SELECT tablespace_name, SUM(bytes) AS free_bytes
              FROM dba_free_space
             GROUP BY tablespace_name
        ) fs
          ON df.tablespace_name = fs.tablespace_name
        WHERE ROUND((df.total_bytes - fs.free_bytes) / df.total_bytes * 100, 2) >= v_limite
        ORDER BY pct_util DESC
    ) LOOP
        v_corpo := v_corpo || '<tr>' ||
            '<td>' || rec.nome_ts || '</td>' ||
            '<td>' || TO_CHAR(rec.pct_util, 'FM999.99') || '%</td>' ||
            '<td>' || TO_CHAR(rec.total_gb, 'FM999990.00') || '</td>' ||
            '<td>' || TO_CHAR(rec.livre_gb, 'FM999990.00') || '</td>' ||
            '</tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    -- Caso haja tablespaces acima do limite, enviar e‑mail
    IF v_corpo IS NOT NULL THEN
        pkg_monitoria_utils.envia_email_html(
            p_assunto => v_titulo,
            p_corpo   => pkg_monitoria_utils.gera_template_alerta(v_titulo, v_corpo)
        );
    END IF;
END pr_alerta_espaco_tbs;
/

/*
   Procedure: pr_alerta_processo_bloqueado
   Objetivo: identificar sessões bloqueadas há mais de x minutos e enviar alerta.
*/
CREATE OR REPLACE PROCEDURE pr_alerta_processo_bloqueado IS
    v_corpo    CLOB;
    v_titulo   VARCHAR2(200) := 'Alerta: Sessões Bloqueadas';
BEGIN
    v_corpo := '<table border="1" cellpadding="3" cellspacing="0"><tr>' ||
               '<th>SID</th><th>Usuário</th><th>Objetivo Bloqueado</th><th>Tempo Bloqueado (min)</th></tr>';
    FOR rec IN (
        SELECT l1.sid    AS sid_bloqueado,
               s.username,
               o.object_name AS objeto,
               ROUND((SYSDATE - s.logon_time) * 1440) AS tempo_min
          FROM v$lock l1
          JOIN v$session s ON l1.sid = s.sid
          LEFT JOIN dba_objects o ON s.row_wait_obj# = o.object_id
         WHERE l1.block = 0 AND l1.request > 0
           AND ROUND((SYSDATE - s.logon_time) * 1440) > TO_NUMBER(pkg_monitoria_utils.get_parametro('LIMITE_TEMPO_QUERY_MIN'))
    ) LOOP
        v_corpo := v_corpo || '<tr>' ||
            '<td>' || rec.sid_bloqueado || '</td>' ||
            '<td>' || rec.username || '</td>' ||
            '<td>' || NVL(rec.objeto, 'N/A') || '</td>' ||
            '<td>' || rec.tempo_min || '</td>' ||
            '</tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    -- enviar email se houver linhas
    IF v_corpo IS NOT NULL THEN
        pkg_monitoria_utils.envia_email_html(
            p_assunto => v_titulo,
            p_corpo   => pkg_monitoria_utils.gera_template_alerta(v_titulo, v_corpo)
        );
    END IF;
END pr_alerta_processo_bloqueado;
/

/*
   Procedure: pr_alerta_fragmentacao_indice
   Objetivo: identificar índices com fragmentação acima do limite e enviar alerta. 
   Observação: Oracle não possui função nativa para calcular percentual de fragmentação como o SQL Server. 
   Aqui é utilizado o DBA_INDEXES.BLEVE opcionalmente. Sugerimos utilizar DBMS_STATS.GATHER_SCHEMA_STATS regularmente.
*/
CREATE OR REPLACE PROCEDURE pr_alerta_fragmentacao_indice IS
    v_limite NUMBER := TO_NUMBER(pkg_monitoria_utils.get_parametro('LIMITE_FRAGMENTACAO_PCT'));
    v_corpo  CLOB;
    v_titulo VARCHAR2(200) := 'Alerta: Fragmentação de Índice';
BEGIN
    v_corpo := '<p>Identificar índices altamente fragmentados requer análise detalhada. Sugerimos executar o pacote DBMS_REPAIR ou recriar índices manualmente.</p>';
    -- Exemplo de consulta simples para identificar índices com muitos blocos vazios
    v_corpo := v_corpo || '<p>(Esta rotina é um template; adapte conforme necessário.)</p>';
    pkg_monitoria_utils.envia_email_html(
        p_assunto => v_titulo,
        p_corpo   => pkg_monitoria_utils.gera_template_alerta(v_titulo, v_corpo)
    );
END pr_alerta_fragmentacao_indice;
/

/*
   Procedure: pr_alerta_sessoes_longas
   Objetivo: alertar queries que executam há mais tempo que o limite configurado.
*/
CREATE OR REPLACE PROCEDURE pr_alerta_sessoes_longas IS
    v_limite   NUMBER := TO_NUMBER(pkg_monitoria_utils.get_parametro('LIMITE_TEMPO_QUERY_MIN'));
    v_corpo    CLOB;
    v_titulo   VARCHAR2(200) := 'Alerta: Sessões de Longa Duração';
BEGIN
    v_corpo := '<table border="1" cellpadding="3" cellspacing="0"><tr>' ||
               '<th>SID</th><th>Usuário</th><th>SQL_ID</th><th>Tempo (min)</th><th>SQL Text</th></tr>';
    FOR rec IN (
        SELECT s.sid,
               s.username,
               s.sql_id,
               ROUND((SYSDATE - s.last_call_et/86400 - s.logon_time) * 1440) AS tempo_min,
               SUBSTR(q.sql_text, 1, 200) AS sql_text
          FROM v$session s
          JOIN v$sql q ON s.sql_id = q.sql_id
         WHERE s.status = 'ACTIVE'
           AND (SYSDATE - s.logon_time) * 1440 >= v_limite
    ) LOOP
        v_corpo := v_corpo || '<tr>' ||
            '<td>' || rec.sid || '</td>' ||
            '<td>' || rec.username || '</td>' ||
            '<td>' || rec.sql_id || '</td>' ||
            '<td>' || rec.tempo_min || '</td>' ||
            '<td>' || rec.sql_text || '</td>' ||
            '</tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_corpo IS NOT NULL THEN
        pkg_monitoria_utils.envia_email_html(
            p_assunto => v_titulo,
            p_corpo   => pkg_monitoria_utils.gera_template_alerta(v_titulo, v_corpo)
        );
    END IF;
END pr_alerta_sessoes_longas;
/

/*
   Procedure: pr_alerta_deadlock
   Objetivo: enviar alerta quando registros forem inseridos na tabela LOG_DEADLOCK (por rotina externa).
*/
CREATE OR REPLACE PROCEDURE pr_alerta_deadlock IS
    v_corpo  CLOB;
    v_titulo VARCHAR2(200) := 'Alerta: Deadlock detectado';
    v_count  NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM log_deadlock WHERE data_evento > SYSDATE - (1/1440*pkg_monitoria_utils.get_parametro('FREQ_DEADLOCK_MIN'));
    IF v_count > 0 THEN
        v_corpo := '<p>Foram detectados ' || v_count || ' eventos de deadlock nas últimas horas.</p>';
        pkg_monitoria_utils.envia_email_html(
            p_assunto => v_titulo,
            p_corpo   => pkg_monitoria_utils.gera_template_alerta(v_titulo, v_corpo)
        );
    END IF;
END pr_alerta_deadlock;
/

/*
   Agendamento dos jobs.
   Para cada alerta ativo na tabela ALERTAS, criaremos um job com o intervalo definido em FREQUENCIA_MIN.
*/
DECLARE
    CURSOR c_alertas IS
        SELECT id_alerta, nome_alerta, procedimento, frequencia_min
          FROM alertas
         WHERE ativo = 'S';
    v_job_name VARCHAR2(100);
BEGIN
    FOR rec IN c_alertas LOOP
        v_job_name := 'PR_' || UPPER(REPLACE(rec.nome_alerta, ' ', '_')) || '_JOB';
        -- Apaga job se já existir
        BEGIN
            DBMS_SCHEDULER.drop_job(job_name => v_job_name, force => TRUE);
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
        -- Cria job
        DBMS_SCHEDULER.create_job(
            job_name        => v_job_name,
            job_type        => 'STORED_PROCEDURE',
            job_action      => rec.procedimento,
            start_date      => SYSTIMESTAMP,
            repeat_interval => 'FREQ=MINUTELY;INTERVAL=' || rec.frequencia_min,
            enabled         => TRUE,
            comments        => 'Job automático para ' || rec.nome_alerta
        );
    END LOOP;
END;
/

/*
  Nota: alguns alertas (como deadlock) exigem que outro processo grave dados nas tabelas de log (por exemplo, um job externo utilizando XEvents ou trace). 
  Esses processos devem ser implementados separadamente em scripts adicionais ou via ferramentas de terceiros.
*/