# Guia de Configuração – Oracle Alertas

Esta seção apresenta instruções detalhadas para configurar os componentes da solução de alertas após a instalação.

## Configuração de SMTP

Conforme descrito no guia de instalação, o envio de e‑mail utiliza o pacote `UTL_MAIL` por padrão. Para funcionar corretamente:

1. **Defina o servidor SMTP** via parâmetro `smtp_out_server`. Caso o servidor exija autenticação ou use TLS/SSL, você pode desenvolver sua própria procedure de envio utilizando `UTL_SMTP`. Um exemplo de implementação se encontra em `tools/exemplos_scripts_envio_email/enviar_email_utl_smtp.sql`.
2. **Conceda privilégios ao usuário de monitoria**: é necessário o privilégio `EXECUTE ON UTL_MAIL` e (quando usando SMTP personalizado) `EXECUTE ON UTL_SMTP`.
3. **Configure remetente e destinatários** na tabela `PARAMETROS_ALERTA`, nos parâmetros `EMAIL_FROM` e `EMAIL_TO`. É possível definir múltiplos destinatários separados por vírgula.

Exemplo:

```sql
UPDATE parametros_alerta SET valor = 'dba@empresa.com' WHERE nome_parametro = 'EMAIL_FROM';
UPDATE parametros_alerta SET valor = 'dba1@empresa.com,dba2@empresa.com' WHERE nome_parametro = 'EMAIL_TO';
COMMIT;
```

## Parâmetros de thresholds

Os valores de limiar (percentual, tempo ou contagem) que disparam alertas são definidos na tabela `PARAMETROS_ALERTA`. Alguns exemplos de parâmetros:

| Parâmetro                 | Descrição                                                                                 |
|--------------------------|-------------------------------------------------------------------------------------------|
| `LIMITE_TABLESPACE_PCT`  | Percentual de uso de tablespace a partir do qual gera alerta (`pr_alerta_espaco_tbs`).    |
| `LIMITE_CPU_PCT`         | Percentual de utilização de CPU que dispara alerta de alto consumo.                       |
| `LIMITE_TEMPO_QUERY_MIN` | Tempo (minutos) de execução de uma consulta para considerá‑la longa.                      |
| `LIMITE_FRAGMENTACAO_PCT`| Percentual de fragmentação de índice para disparar reindexação ou alerta.                  |

Ajuste cada um conforme a criticidade do seu ambiente. Novos parâmetros podem ser adicionados se criar novas procedures; basta inserir a linha em `PARAMETROS_ALERTA` e referenciá‑la no código.

## Configuração de jobs

Todos os jobs são criados via `DBMS_SCHEDULER` com repetição configurável. Para alterar a periodicidade de um job, execute:

```sql
BEGIN
  DBMS_SCHEDULER.disable(name => 'MONITORING.PR_ALERTA_ESPACO_TBS_JOB');
  DBMS_SCHEDULER.set_attribute(
    name      => 'MONITORING.PR_ALERTA_ESPACO_TBS_JOB',
    attribute => 'repeat_interval',
    value     => 'FREQ=HOURLY;INTERVAL=1'
  );
  DBMS_SCHEDULER.enable(name => 'MONITORING.PR_ALERTA_ESPACO_TBS_JOB');
END;
/
```

Para visualizar jobs:

```sql
SELECT job_name, state, repeat_interval, last_start_date
  FROM user_scheduler_jobs
 WHERE job_name LIKE 'PR_ALERTA_%';
```

## Personalizando templates de e‑mail

Os procedimentos de envio de alerta constroem mensagens em formato HTML. Os templates básicos ficam nas funções utilitárias (package `PKG_MONITORIA_UTILS`). Você pode editar o template para incluir logotipo da empresa, cores específicas ou informações adicionais. Procure pela função `gera_template_alerta` no arquivo `2.1_cria_procedures_e_jobs_oracle.sql` e ajuste conforme necessário.

## Boas práticas adicionais

1. **Isolar a carga**: agende tarefas pesadas (como coleta de estatísticas) fora dos horários de pico.
2. **Manter estatísticas atualizadas**: monitore o valor de `STALE_STATS` em `DBA_TAB_STATISTICS` e programe uma coleta automática (`DBMS_STATS`).
3. **Monitorar espaço de FRA (Flash Recovery Area)**: configure alerta específico para quando a FRA ultrapassar 80 % de ocupação.
4. **Auditar falhas de jobs**: revise regularmente a visão `DBA_SCHEDULER_JOB_RUN_DETAILS` em busca de registros com `STATUS = 'FAILED'` e trate as causas.
