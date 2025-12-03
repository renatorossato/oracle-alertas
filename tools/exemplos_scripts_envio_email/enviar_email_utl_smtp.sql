/*
    Exemplo de envio de e‑mail utilizando UTL_SMTP em vez de UTL_MAIL.
    Use este script caso precise de autenticação TLS ou customizações avançadas.
    Ajuste host, porta, remetente, destinatário e corpo conforme necessário.
*/
DECLARE
    l_connection  UTL_SMTP.connection;
    l_host        VARCHAR2(100) := 'smtp.seu-servidor.com';
    l_port        PLS_INTEGER := 25;
    l_user        VARCHAR2(100) := 'usuario';
    l_pass        VARCHAR2(100) := 'senha';
    l_from        VARCHAR2(200) := 'monitor@empresa.com';
    l_to          VARCHAR2(2000) := 'dba@empresa.com';
    l_subject     VARCHAR2(200) := 'Alerta de Teste';
    l_body        CLOB := '<html><body><h2>Teste</h2><p>Este é um envio de teste via UTL_SMTP.</p></body></html>';
BEGIN
    l_connection := UTL_SMTP.open_connection(l_host, l_port);
    -- Autenticação básica (LOGIN) se necessária
    UTL_SMTP.ehlo(l_connection, l_host);
    UTL_SMTP.login(l_connection, l_user, l_pass);
    UTL_SMTP.mail(l_connection, l_from);
    UTL_SMTP.rcpt(l_connection, l_to);
    UTL_SMTP.open_data(l_connection);
    UTL_SMTP.write_data(l_connection, 'From: ' || l_from || CHR(13)||CHR(10));
    UTL_SMTP.write_data(l_connection, 'To: ' || l_to || CHR(13)||CHR(10));
    UTL_SMTP.write_data(l_connection, 'Subject: ' || l_subject || CHR(13)||CHR(10));
    UTL_SMTP.write_data(l_connection, 'MIME-Version: 1.0' || CHR(13)||CHR(10));
    UTL_SMTP.write_data(l_connection, 'Content-Type: text/html; charset=UTF-8' || CHR(13)||CHR(10));
    UTL_SMTP.write_data(l_connection, CHR(13)||CHR(10));
    UTL_SMTP.write_data(l_connection, l_body);
    UTL_SMTP.close_data(l_connection);
    UTL_SMTP.quit(l_connection);
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
/