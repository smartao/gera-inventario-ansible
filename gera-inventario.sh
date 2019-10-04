#!/bin/bash
#
source /usr/local/bin/gera-inventario-ansible/variaveis # Carregando arquivo que contem as variaveis
mkdir $DIR > /dev/null 2>&1 # Criando o diretorio para os relatorios
rm $DIR/rel* > /dev/null 2>&1 # Deletar os relatorio já criados

# Funcao principal MAIN que executara as demais funcoes
function MAIN(){
	CARREGASERVIDORES
	COLETAINFO
	VALIDASSH
	GERAINVENTARIOS
}
# Funcao que faz a query no banco de dados e armazenar todas as informacoes em vetores
function CARREGASERVIDORES(){
	# Conectando no banco de dados, fazendo query e ignorando host conforme arquivo apontado na variavel 
	mysql $CONEXAO -e "$QUERY" | sed 's/\t/;/g' | sed '1d;$d' | grep -vi -f $HOSTIGNORADOS > $DIR/$ARQF

    a=1 # Definindo valor da variavel de controle para o loop while
	while read i;do # laco para ler as informacoes do arquivo e armazenar todas as informacoes em vetores
		CI[$a]=`echo $i | cut -d\; -f1` # Armazenando em vetor o campo CI
		IP[$a]=`echo $i | cut -d\; -f2 | cut -d" " -f1 | cut -d\, -f1` # Armazenando em vetor e tratando o campo IP
		TIPO[$a]=`echo $i | cut -d\; -f3` # Armazenando em vetor o campo TIPO
		SITE[$a]=`echo $i | cut -d\; -f4` # Armazenando em vetor o campo SITE
		#DESC[$a]=`echo $i | cut -d\; -f4` # Armazenando em vetor o campo Descricao
	let a=$a+1 # Incrementando valor da variavel de controle do while
	done < $DIR/$ARQF # Adicionando arquivo que o while lera
}
# Funcao para vetorizar as informacoes do tipo de servidor e sites disponiveis 
# para gerar o arquivo de relatorio por localidade e tipo de servidor
# tipo de servidor = desenvolvimento, infraestrutura, suporte a desenvolviment
# site = saopaulo, riodejanerio, marechal, azure, vivocloud
function COLETAINFO(){
    b=1 # Definindo o valor inicial da variavel de controle
    cat $DIR/$ARQF | cut -d\; -f4 | sort | uniq > $DIR/$ARQT; # Filtrando os sites disponiveis
    while read i;do # Loop para ler o arquivo linha por linha e armazenar os sites no vetor
        LISTASITE[$b]=$i # Armazenando o sites no vetor
        let b=$b+1 # Incrementando a variavel de controle
    done < $DIR/$ARQT # colocando o arquivo para o while ler
    
    b=1 # Definindo o valor inicial da variavel de controle
    cat $DIR/$ARQF | cut -d\; -f3 | sort | uniq > $DIR/$ARQT; # Filtando os tipos de servidores disponiveis
    while read i;do # Loop para ler o arquivo linha por linha e armzenar o tipo de servidor no vetor
        LISTATIPO[$b]=$i # Armazenando a localidade do servidor no vetor
        let b=$b+1 # Incrementando a variavel de controle do vetor
    done < $DIR/$ARQT # Colocando o arquivo para o while ler
    rm $DIR/$ARQT > /dev/null 2>&1 # removendo arquivo temporario
}
function VALIDASSH(){ # Funcao para validar em qual porta SSH o servidor esta ouvindo
	for((s=1;s<=${#IP[@]};s++));do # Loop que corre todos os IPs armazenado anteriormente
		PORTASSH[$s]=0 # Defnindo valor padrao "0", caso a porta SSH nao seja identificada
		for((a=1;a<=${#PORTA[@]};a++));do # Validando todas as portas ssh disponiveis
            # Executando nmap no IP mais porta SSH e validando se o status e open
            STATUSSSH=`timeout $TIME nmap ${IP[$s]} -n -sT -Pn -p${PORTA[$a]} | grep -i ${PORTA[$a]} | grep -i tcp | cut -d' ' -f2`
			if [ $STATUSSSH == "open" ];then # caso a prota esteja aberta no servidor
				PORTASSH[$s]=${PORTA[$a]} # armanzenar o numero da porta no vetor PORTASSH
			fi
		done
	done
}
function GERAINVENTARIOS(){ # Funcao para gerar relatorio na padrao do ansible IP:Porta
	> $DIR/$RELFULL # Limpar arquivo de relatorio de servidores
    for((s=1;s<=${#IP[@]};s++));do # Loop para correr todos os IP do relatorio
        # Gerando relatorio full com todos os hosts
        echo "${CI[$s]} ansible_ssh_host=${IP[$s]} ansible_ssh_port=${PORTASSH[$s]}" >> $DIR/$RELFULL # Gerando reladorio completo em unico arquivo
        for((a=1;a<=${#LISTASITE[@]};a++));do # Loop que corre toda LISTASITE
            # Se o SITE do host for igual a lista do Site
            if [ "${SITE[$s]}" == "${LISTASITE[$a]}" ];then
                # Imprimindo no arquivo IP e porta SSH
                echo "${CI[$s]} ansible_ssh_host=${IP[$s]} ansible_ssh_port=${PORTASSH[$s]}" >> $DIR/"rel-${LISTASITE[$a]// /-}-all"
                for((m=1;m<=${#LISTATIPO[@]};m++));do # Loop que corre todos os tipo de servidores LISTATIPO
                    if [ "${TIPO[$s]}" == "${LISTATIPO[$m]}" ];then
                        # Se o TIPO do host for igual a LISTATIPO, gera arquivo com o tipo
                        echo "${CI[$s]} ansible_ssh_host=${IP[$s]} ansible_ssh_port=${PORTASSH[$s]}" >> $DIR/"rel-${LISTASITE[$a]// /-}-${LISTATIPO[$m]// /-}"
                    fi
                done
            fi
        done
    done
    # Adicionando [all] no inicio do arquivos necessário para o ansible funcionar e alterando para letras minusculas
    for i in `ls $DIR/rel-*`;do # loop que le todos os arquivos comecados por "rel-"
         sed -i '1 i\[all]' $i # Sed que adiciona [all] na primeira linha
         if [ $i != ${i,,} ];then # Se os arquivos estiverem com letras maiusculas
             mv $i ${i,,} # Renomeando os arquivos, trocando letras maisculas apenas letras minusculas
         fi
     done
}
MAIN # Executandoa funcao principal MAIN
exit;
