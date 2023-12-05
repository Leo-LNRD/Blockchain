// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Loteria
{
    bool private loteria_ativa;
    bool private loteria_manual;
    bool private bypass;

    uint64 private participantes_totais;
    uint256 private limite_acumulo;
    uint256 private premiacao;
    uint256 private seed;
    uint256 private id;

    address private admin;
    address [] private participantes;

    mapping(address => uint256) private entradas;
    mapping(address => uint256) private numeros;
    mapping(address => bool) private participando;

    event TrocaAdmin (address indexed adminAntigo, address indexed adminNovo);
    event LoteriaCriada (uint256 idLoteria, bool modo, uint256 limite);    
    event NovoParticipante (uint256 idLoteria, address indexed endereco);
    event SaidaParticipante (uint256 idLoteria, address indexed endereco);
    event LoteriaEncerrada (uint256 idLoteria, address indexed ganhador, uint256 premio);

    constructor ()
    {
        admin = msg.sender;
        seed = block.number;
        bypass = false;
        loteria_ativa = false;
        participantes_totais = 0;
        id = 0;
    }

    modifier ativa ()
    {
        require (loteria_ativa, "Loteria fechada.");
        _;
    }

    modifier restrito ()
    {
        require (msg.sender == admin || bypass, "Somente o administrador pode executar esta funcionalidade.");
        _;
    }

    modifier competindo ()
    {
        require (participando[msg.sender], "Usuario esta fora da loteria.");
        _;
    }

    function iniciar (uint8 modo, uint256 limite) public restrito ()
    {
        require (!loteria_ativa, "Loteria em andamento.");

        if (modo != 0) loteria_manual = false;
        else           loteria_manual = true;

        resetar_variaveis();

        limite_acumulo = limite;
        loteria_ativa = true;
        id++;

        emit LoteriaCriada(id, loteria_manual, limite);
    }

    function entrar () public payable ativa  // atualizar
    {
        require (msg.value > 0, "Precisa depositar um valor para entrar na loteria.");

        if (!participando[msg.sender])
        {
            participando[msg.sender] = true;
            participantes.push(msg.sender);
            participantes_totais += 1;

            emit NovoParticipante(id, msg.sender);
        }

        entradas[msg.sender] += msg.value;
        premiacao += msg.value;

        if (!loteria_manual && premiacao >= limite_acumulo)
        {
            bypass = true;
            sortear();
            bypass = false;
        }
    }

    function sair () public ativa competindo
    {
        payable(msg.sender).transfer(entradas[msg.sender]);

        atualiza_participantes(msg.sender);
        premiacao -= entradas[msg.sender];
        participantes_totais -= 1;

        delete entradas[msg.sender];
        delete participando[msg.sender];

        emit SaidaParticipante(id, msg.sender);
    }

    function sortear () public restrito ativa
    {
        require (participantes_totais > 0, "Loteria sem participantes.");

        uint256 min = consulta_minimo();
        uint256 total_numeros = 0;
        uint256 sorteado;

        address ganhador;

        for (uint256 i = 0; i < participantes_totais; i++)
        {
            total_numeros += entradas[participantes[i]] / min;
            numeros[participantes[i]] = total_numeros;
        }

        sorteado = (random() % total_numeros) + 1;
        loteria_ativa = false;

        for (uint256 i = 0; i < participantes_totais; i++)
        {
            if (sorteado <= numeros[participantes[i]])
            {
                ganhador = participantes[i];
                break;
            }
        }

        payable(ganhador).transfer(premiacao);
        emit LoteriaEncerrada(id, ganhador, premiacao);
    }

    function mudar_admin (address novoAdmin) public restrito
    {
        require (novoAdmin != address(0), "Endereco invalido.");
        
        address tmp = admin;
        admin = novoAdmin;

        emit TrocaAdmin(tmp, admin);
    }

    function consultar_entrada () public view ativa competindo returns (uint256)  
    {
        return entradas[msg.sender];
    }

    function consultar_premiacao () public view ativa returns (uint256)
    {
        return premiacao;
    }

    function consultar_participantes () public view restrito ativa returns (uint256, address [] memory)
    {
        return (participantes.length, participantes);
    }

    function resetar_variaveis () private 
    {
        for (uint256 i = 0; i < participantes_totais; i++)
        {
            delete entradas[participantes[i]];
            delete numeros[participantes[i]];
            delete participando[participantes[i]];
        }

        participantes = new address[](0);
        participantes_totais = 0;
        premiacao = 0;
    }

    function atualiza_participantes (address alvo) private 
    {
        bool found = false;
        uint256 pos;

        for (uint256 i = 0; i < participantes_totais; i++)
        {
            if (participantes[i] == alvo) 
            {
                found = true;
                pos = i;
                break;
            }
        }

        if (!found) revert("Erro em deletar participante.");

        for (uint256 i = pos; i < participantes_totais - 1; i++)
        {
            participantes[i] = participantes[i + 1];
        }

        participantes.pop();
    }

    function consulta_minimo () private view returns (uint256) 
    {
        uint256 min = entradas[participantes[0]];

        for (uint256 i = 1; i < participantes_totais; i++)
        {
            if (entradas[participantes[i]] < min)
            {
                min = entradas[participantes[i]];
            }
        }

        return min;
    }

    function random () private view returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), seed, block.timestamp)));
    }
}
