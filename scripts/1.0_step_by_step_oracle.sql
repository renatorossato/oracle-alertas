/*
    Objetivo: roteiro passo a passo para instalar os alertas em um banco Oracle.
    Banco alvo: Oracle Database 12c ou superior.
    Pré‑requisitos: ver README.md e guia_instalacao.md.
    Responsável: Adaptado do projeto Script_SQLServer_Alerts.
    Histórico de versões:
      v1.0 - Criação inicial do roteiro de instalação para Oracle.

    Instruções:
    1. Leia atentamente este arquivo. Ele não deve ser executado diretamente; serve como orientação.
    2. Conecte‑se como usuário de monitoria (por exemplo, MONITORING) via SQL*Plus ou SQLcl.
    3. Execute os scripts na ordem indicada abaixo utilizando o comando @.

    Passo a passo:
    ---------------------------------------------------------------
    -- 1. Crie o esquema e conceda privilégios (ver guia_instalacao).
    -- 2. Execute o script de criação de tabelas e parâmetros de alerta:
    --      @2.0_cria_tabelas_alertas.sql
    -- 3. Execute o script de criação de procedures de alerta e jobs:
    --      @2.1_cria_procedures_e_jobs_oracle.sql
    -- 4. (Opcional) Execute o script de verificação de corrupção (DBVERIFY):
    --      @3.0_checkdb_oracle.sql
    -- 5. Execute o script de checklist diário:
    --      @4.0_checklist_procedures_oracle.sql
    -- 6. Revise e ajuste parâmetros de alerta na tabela PARAMETROS_ALERTA.
    -- 7. Teste os alertas conforme descrito no guia_instalacao.

    Observação:
    Os scripts devem ser executados apenas uma vez na instalação inicial. Em caso de atualizações futuras, consulte o CHANGELOG.md para scripts de migração específicos.
*/

-- Este script contém somente comentários. As execuções devem ser realizadas conforme o roteiro acima.