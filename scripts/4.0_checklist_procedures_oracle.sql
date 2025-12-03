/*
    Objetivo: criar procedures para gerar checklist diário com métricas de ambiente e enviar relatório consolidado.
    Banco alvo: Oracle Database.
    Adaptado do script original 4.0 - Procedures CheckList.sql para SQL Server.
    Este script cria:
      - Procedures de coleta (pr_checklist_espaco_disco, pr_checklist_sessoes, etc.)
      - Procedure agregadora pr_checklist_diario que chama as demais e compõe e‑mail.
      - Tabela para histórico de checklist (checklist_historico).
      - Job agendado no DBMS_SCHEDULER para execução diária.

    Histórico de versões:
      v1.0 - Implementação simplificada do checklist.
*/

-- Tabela de histórico do checklist diário
CREATE TABLE checklist_historico (
    id_checklist    NUMBER PRIMARY KEY,
    data_execucao   DATE DEFAULT SYSDATE,
    relatorio_html  CLOB
);
CREATE SEQUENCE seq_checklist START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

/*
  Procedure: pr_checklist_espaco_disco
  Coleta uso de tablespace em resumo e retorna HTML com tabela.
*/
CREATE OR REPLACE FUNCTION pr_checklist_espaco_disco RETURN CLOB IS
    v_corpo CLOB;
BEGIN
    v_corpo := '<h3>Espaço em Tablespaces</h3>' ||
               '<table border="1" cellpadding="3" cellspacing="0"><tr>' ||
               '<th>Tablespace</th><th>Tamanho (GB)</th><th>Livre (GB)</th><th>% Utilizado</th></tr>';
    FOR rec IN (
        SELECT df.tablespace_name   AS nome_ts,
               ROUND(df.total_bytes/1024/1024/1024,2) AS total_gb,
               ROUND(fs.free_bytes/1024/1024/1024,2) AS livre_gb,
               ROUND((df.total_bytes - fs.free_bytes) / df.total_bytes * 100, 2) AS pct_util
          FROM (
                SELECT tablespace_name, SUM(bytes) AS total_bytes
                  FROM dba_data_files
                 GROUP BY tablespace_name
               ) df
          JOIN (
                SELECT tablespace_name, SUM(bytes) AS free_bytes
                  FROM dba_free_space
                 GROUP BY tablespace_name
               ) fs ON df.tablespace_name = fs.tablespace_name
          ORDER BY pct_util DESC
    ) LOOP
        v_corpo := v_corpo || '<tr><td>' || rec.nome_ts || '</td>' ||
                            '<td>' || rec.total_gb || '</td>' ||
                            '<td>' || rec.livre_gb || '</td>' ||
                            '<td>' || rec.pct_util || '%</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    RETURN v_corpo;
END;
/

/*
  Function: pr_checklist_sessoes_ativas
  Lista top 5 sessões ativas ordenadas por tempo de execução.
*/
CREATE OR REPLACE FUNCTION pr_checklist_sessoes_ativas RETURN CLOB IS
    v_corpo CLOB;
    v_count NUMBER := 0;
BEGIN
    v_corpo := '<h3>Sessões Ativas de Longa Duração</h3>' ||
               '<table border="1" cellpadding="3" cellspacing="0"><tr>' ||
               '<th>SID</th><th>Usuário</th><th>Tempo (min)</th><th>SQL Text</th></tr>';
    FOR rec IN (
        SELECT * FROM (
            SELECT s.sid,
                   s.username,
                   ROUND((SYSDATE - s.logon_time) * 1440) AS tempo_min,
                   SUBSTR(q.sql_text,1,200) AS sql_text
              FROM v$session s
              JOIN v$sql q ON s.sql_id = q.sql_id
             WHERE s.status = 'ACTIVE' AND s.username IS NOT NULL
             ORDER BY (SYSDATE - s.logon_time) DESC
        )
        WHERE ROWNUM <= 5
    ) LOOP
        v_count := v_count + 1;
        v_corpo := v_corpo || '<tr><td>' || rec.sid || '</td>' ||
                                '<td>' || rec.username || '</td>' ||
                                '<td>' || rec.tempo_min || '</td>' ||
                                '<td>' || rec.sql_text || '</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_count = 0 THEN
        v_corpo := v_corpo || '<p>Não há sessões em execução no momento da coleta.</p>';
    END IF;
    RETURN v_corpo;
END;
/

/*
  Function: pr_checklist_jobs
  Lista jobs do scheduler que falharam nas últimas 24 horas.
*/
CREATE OR REPLACE FUNCTION pr_checklist_jobs RETURN CLOB IS
    v_corpo CLOB;
    v_count NUMBER := 0;
BEGIN
    v_corpo := '<h3>Jobs com Falha nas Últimas 24h</h3>' ||
               '<table border="1" cellpadding="3" cellspacing="0"><tr>' ||
               '<th>Job</th><th>Status</th><th>Última Execução</th><th>Erro</th></tr>';
    FOR rec IN (
        SELECT job_name,
               status,
               TO_CHAR(actual_start_date, 'DD/MM/YYYY HH24:MI') AS inicio,
               SUBSTR(additional_info,1,200) AS erro
          FROM user_scheduler_job_run_details
         WHERE log_date > SYSDATE - 1
           AND status = 'FAILED'
         ORDER BY log_date DESC
    ) LOOP
        v_count := v_count + 1;
        v_corpo := v_corpo || '<tr><td>' || rec.job_name || '</td>' ||
                                 '<td>' || rec.status || '</td>' ||
                                 '<td>' || rec.inicio || '</td>' ||
                                 '<td>' || rec.erro || '</td></tr>';
    END LOOP;
    v_corpo := v_corpo || '</table>';
    IF v_count = 0 THEN
        v_corpo := v_corpo || '<p>Nenhum job falhou nas últimas 24 horas.</p>';
    END IF;
    RETURN v_corpo;
END;
/

/*
  Procedure: pr_checklist_diario
  Agrega o resultado das funções acima e envia relatório consolidado por e‑mail.
*/
CREATE OR REPLACE PROCEDURE pr_checklist_diario IS
    v_relatorio CLOB;
    v_titulo    VARCHAR2(200) := 'Checklist Diário – ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY');
BEGIN
    v_relatorio := pr_checklist_espaco_disco || pr_checklist_sessoes_ativas || pr_checklist_jobs;
    -- Inserir no histórico
    INSERT INTO checklist_historico (id_checklist, relatorio_html)
    VALUES (seq_checklist.NEXTVAL, v_relatorio);
    COMMIT;
    -- Enviar por e‑mail
    pkg_monitoria_utils.envia_email_html(
        p_assunto => v_titulo,
        p_corpo   => pkg_monitoria_utils.gera_template_alerta(v_titulo, v_relatorio)
    );
END pr_checklist_diario;
/

/*
  Agendar o job diário – padrão às 06:55. Ajuste conforme necessidade.
*/
BEGIN
    DBMS_SCHEDULER.drop_job('PR_CHECKLIST_DIARIO_JOB', force => TRUE);
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/
BEGIN
    DBMS_SCHEDULER.create_job(
        job_name        => 'PR_CHECKLIST_DIARIO_JOB',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'PR_CHECKLIST_DIARIO',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY;BYHOUR=6;BYMINUTE=55;BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Gera e envia checklist diário de monitoria'
    );
END;
/