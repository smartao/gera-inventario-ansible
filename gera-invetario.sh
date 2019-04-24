#!/bin/bash

# Carregando variaveis necessarios
source variaveis

# Executando script por funcoes
function MAIN(){
	CARREGASERVIDORES
    COLETAINFO
	VALIDASSH
    GERAINVENTARIOS
}
# funcao com objetivo de fazer a query no banco de dados e armazenar todas as informacoes em vetores
function CARREGASERVIDORES(){
	# Fazendo query no bando de dados e ignorando host conforme arquivo armazenado na variavel 
	mysql $CONEXAO -e "$QUERY" | sed 's/\t/;/g' | sed '1d;$d' | grep -vi -f $HOSTIGNORADOS > $DIR/$ARQT

	a=1 # Definindo valor da variavel de controle do while a baixo
	while read i;
	do 
		CI[$a]=`echo $i | cut -d\; -f1` # Armazenando em vetor o campo CI
		IP[$a]=`echo $i | cut -d\; -f2 | cut -d" " -f1 | cut -d\, -f1` # Armazenando em vetor e tratando o campo IP
		TIPO[$a]=`echo $i | cut -d\; -f3` # Armazenando em vetor o campo TIPO
		SITE[$a]=`echo $i | cut -d\; -f4` # Armazenando em vetor o campo SITE
		#DESC[$a]=`echo $i | cut -d\; -f4` # Armazenando em vetor o campo Descricao
	let a=$a+1 # incrementando valor da variavel de controle do while
	done < $DIR/$ARQT # adicionando arquivo que o while lera

}
# funcao para vetorizar as informacoes do tipo de servidor e localidades dos servidores 
# para gerar o arquivo de relatorio por localidade e tipo de servidor
function COLETAINFO(){
    b=1 # Definindo o valor inicial da variavel de controle
    cat $DIR/$ARQT | cut -d\; -f4 | sort | uniq > $DIR/t; # Filtando as localidade disponiveis
    while read i;
    do 
        LISTASITE[$b]=$i # Armazenando a localidade do servidor no vetor
        let b=$b+1 # Incrementando a variavel de controle do vetor
    done < $DIR/t
    
    b=1 
    cat $DIR/$ARQT | cut -d\; -f3 | sort | uniq > $DIR/t; # Filtando os tipos de servidores disponiveis
    while read i;
    do 
        LISTATIPO[$b]=$i # Armazenando a localidade do servidor no vetor
        let b=$b+1 # Incrementando a variavel de controle do vetor
    done < $DIR/t
}

# funcao para validar em qual porta SSH o servidor esta ouvindo
function VALIDASSH(){
	for((s=1;s<=${#IP[@]};s++));
	do
		PORTASSH[$s]=0 # Setando que o padrao e a porta estar fechado
		STATUSSH[$s]=2 # E o status de igorado
		for((a=1;a<=${#PORTA[@]};a++)); # Validando todas as portas ssh disponiveis
		do
            # Executando nmap no IP mais porta SSH e validando se o status é open
            STATUSSSH=`timeout $TIME nmap ${IP[$s]} -n -sT -Pn -p${PORTA[$a]} | grep -i ${PORTA[$a]} | grep -i tcp | cut -d' ' -f2`
			if [ $STATUSSSH == "open" ];then # caso a prota esteja aberta no servidor
				PORTASSH[$s]=${PORTA[$a]} # armanzenar o numero da porta no vetor PORTASSH
				STATUSSH[$s]=1
			fi
		done
	done

}
function GERAINVENTARIOS(){
    # Gerando relatorio full
    echo "[all]" > $DIR/inventariofull
    for((s=1;s<=${#IP[@]};s++)); # loop para correr todos os IP do relatorio
    do
        echo ${IP[$s]}:${PORTASSH[$s]} >> $DIR/inventariofull
        for((a=1;a<=${#LISTASITE[@]};a++));
        do 
            if [ "${SITE[$s]}" == "${LISTASITE[$a]}" ];then
                echo "${IP[$s]}:${PORTASSH[$s]}" >> $DIR/"rel-${LISTASITE[$a]// /-}-all"
                for((m=1;m<=${#LISTATIPO[@]};m++));
                do
                    if [ "${TIPO[$s]}" == "${LISTATIPO[$m]}" ];then
                        echo "${IP[$s]}:${PORTASSH[$s]}" >> $DIR/"rel-${LISTASITE[$a]// /-}-${LISTATIPO[$m]// /-}"
                    fi
                done
            fi
        done
    done
    # Corrigindo arquivos para ter o [all] necessario no ansible
    for i in `ls $DIR/rel-*`;
    do
        sed -i '1 i\[all]' $i
    done
}
MAIN
exit;
