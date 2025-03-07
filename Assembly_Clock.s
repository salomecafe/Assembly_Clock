.arch armv7ve              
.equ UART, 0xFF201000      @ Endereço do UART

.section .text            
.global _start            

_start:
    LDR R0, =horas         @ Carrega endereço da variável 'horas' em R0
    LDR R1, =minutos       @ Carrega endereço da variável 'minutos' em R1
    LDR R2, =segundos      @ Carrega endereço da variável 'segundos' em R2

loop:
    BL incrementar_tempo   @ Função para atualizar horas, minutos e segundos
    BL exibir_relogio      @ Função para exibir o tempo formatado no UART
    BL delay               @ Função para simular a passagem de 1 segundo (aproximadamente)
    B loop                 @ Loop para repetir o processo indefinidamente

@ ================================================
@ incrementar_tempo - Atualiza o relógio
@ ================================================
incrementar_tempo:
    PUSH {R0-R2, R4-R5, LR} @ Preserva os registos (incluindo o Link Register)

    @ Carrega valores atuais da memória
    LDR R3, [R0]           @ R3 = valor atual das horas
    LDR R4, [R1]           @ R4 = valor atual dos minutos
    LDR R5, [R2]           @ R5 = valor atual dos segundos

    @ Lógica de incremento dos segundos
    ADD R5, R5, #1         @ Adiciona 1 segundo
    CMP R5, #60            @ Verifica se ultrapassou 59 segundos
    BLT fim_segundos       @ Se não, salta o reset dos segundos
    MOV R5, #0             @ Faz reset aos segundos para 0
    ADD R4, R4, #1         @ Incrementa minutos (+1 minuto)

fim_segundos:
    @ Lógica de incremento dos minutos
    CMP R4, #60            @ Verifica se ultrapassou 59 minutos
    BLT fim_minutos        @ Se não, salta o reset dos minutos
    MOV R4, #0             @ Faz reset aos minutos para 0
    ADD R3, R3, #1         @ Incrementa horas (+1 hora)

fim_minutos:
    @ Lógica de incremento das horas
    CMP R3, #24            @ Verifica se ultrapassou 23 horas
    BLT fim_horas          @ Se não, salta o reset das horas
    MOV R3, #0             @ Faz reset às horas para 0

fim_horas:
    @ Armazena novos valores na memória
    STR R3, [R0]           @ Atualiza horas na memória
    STR R4, [R1]           @ Atualiza minutos na memória
    STR R5, [R2]           @ Atualiza segundos na memória

    POP {R0-R2, R4-R5, LR} @ Restaura os registos
    BX LR                  @ Volta ao loop principal

@ ================================================
@ exibir_relogio - Exibe o tempo formatado via UART
@ ================================================
exibir_relogio:
    PUSH {R0-R2, R3-R5, LR} @ Preserva todos os registos usados

    @ Recarrega valores da memória (para garantir dados atualizados)
    LDR R0, =horas         @ Recarrega endereço das horas
    LDR R3, [R0]           @ R3 = valor atual das horas
    LDR R1, =minutos       @ Recarrega endereço dos minutos
    LDR R4, [R1]           @ R4 = valor atual dos minutos
    LDR R2, =segundos      @ Recarrega endereço dos segundos
    LDR R5, [R2]           @ R5 = valor atual dos segundos

    @ Envio do formato HH:MM:SS para UART
    MOV R0, R3             @ Prepara horas para envio
    BL enviar_numero       @ Envia valor das horas
    MOV R0, #':'           @ Carrega caractere separador
    BL enviar_caractere    @ Envia ':'
    
    MOV R0, R4             @ Prepara minutos para envio
    BL enviar_numero       @ Envia valor dos minutos
    MOV R0, #':'           @ Carrega caractere separador
    BL enviar_caractere    @ Envia ':'
    
    MOV R0, R5             @ Prepara segundos para envio
    BL enviar_numero       @ Envia valor dos segundos

    @ Limpeza visual: dois espaços + carriage return
    MOV R0, #' '           @ Espaço para sobrescrever possíveis caracteres residuais
    BL enviar_caractere    
    MOV R0, #' '           
    BL enviar_caractere    
    MOV R0, #'\r'          @ Retorno ao início da linha (\r) sem nova linha (\n)
    BL enviar_caractere    

    POP {R0-R2, R3-R5, LR} @ Restaura os registos
    BX LR                  @ Volta ao loop principal

@ ================================================
@ enviar_numero - Converte número para 2 dígitos ASCII
@ ================================================
enviar_numero:
    PUSH {R4, R5, R6, LR}  @ Preserva os registos
    
    MOV R1, #10            @ Divisor para separação decimal
    MOV R2, #0             @ Contador de dígitos
    LDR R6, =buffer        @ Buffer temporário (4 bytes alinhados)

converter_digitos:
    UDIV R3, R0, R1        @ Divide R0 por 10 (R3 = quociente)
    MUL R4, R3, R1         @ Multiplica quociente por 10 (R4 = parte alta)
    SUB R5, R0, R4         @ Obtém dígito menos significativo (R5 = resto)
    ADD R5, #'0'           @ Converte para ASCII
    STRB R5, [R6, R2]      @ Armazena no buffer
    ADD R2, #1             @ Incrementa contador de posição
    MOV R0, R3             @ Atualiza valor para próxima divisão
    CMP R0, #0             @ Verifica se terminou
    BNE converter_digitos  @ Repete se ainda há dígitos

    @ Garante dois dígitos (ex: 05 em vez de 5)
    CMP R2, #2             
    BGE enviar_digitos     
    MOV R5, #'0'           @ Adiciona zero à esquerda
    STRB R5, [R6, R2]      
    ADD R2, #1             

enviar_digitos:
    SUB R2, #1             @ Ajusta contador para índice do buffer
    LDRB R0, [R6, R2]      @ Carrega dígito do buffer
    BL enviar_caractere    @ Envia dígito
    CMP R2, #0             @ Verifica se terminou
    BNE enviar_digitos     @ Repete se ainda há dígitos

    POP {R4, R5, R6, LR}   @ Restaura os registos
    BX LR                  

@ ================================================
@ enviar_caractere - Envia um caractere para UART
@ ================================================
enviar_caractere:
    PUSH {R1, R2, R3, R4}  @ Preserva os registos
    
    LDR R1, =UART          @ Carrega endereço do UART
    MOV R4, #1000          @ Contador de tentativas (timeout)

uart_loop:
    LDR R2, [R1, #4]       @ Lê registrador de controle (offset 4)
    LDR R3, =0xFFFF0000    @ Máscara para isolar o bit de "pronto para transmitir"
    ANDS R2, R3            @ Aplica máscara
    BNE uart_ready         @ Se pronto, envia caractere
    SUBS R4, #1            @ Decrementa contador de timeout
    BNE uart_loop          @ Repete se não atingiu timeout
    B uart_fail            @ Timeout atingido

uart_ready:
    STR R0, [R1]           @ Escreve caractere no registrador de dados

uart_fail:
    POP {R1, R2, R3, R4}   @ Restaura os registos
    BX LR                  

@ ================================================
@ delay - Gera um atraso aproximado de 1 segundo
@ ================================================
delay:
    PUSH {R6, LR}          @ Preserva os registos
    
    LDR R6, =6800000       @ Valor para ~1 segundo
delay_loop:
    SUBS R6, #1            @ Decrementa contador
    BNE delay_loop         @ Continua até contador chegar a zero

    POP {R6, LR}           @ Restaura os registos
    BX LR                  

@ ================================================
@ Seção de dados inicializados
@ ================================================
.data
.align 2                   @ Alinhamento de 4 bytes (garante acesso eficiente)
horas:      .word 0        @ Variável para armazenar horas (32 bits)
minutos:    .word 0        @ Variável para armazenar minutos (32 bits)
segundos:   .word 0        @ Variável para armazenar segundos (32 bits)
buffer:     .space 4       @ Buffer temporário para conversão de dígitos (4 bytes alinhados)