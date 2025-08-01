<script>
  import { onMount, onDestroy } from 'svelte';
  
  // 게임 상태
  let gamePhase = 'login'; // login, waiting, playing, result, gameOver
  let playerId = '';
  let opponentId = '';
  let playerScore = 0;
  let opponentScore = 0;
  let round = 1;
  let maxRounds = 10;
  
  // 선택 관련
  let playerChoice = '';
  let opponentChoice = '';
  let playerReady = false;
  let opponentReady = false;
  let roundResult = '';
  
  // WebSocket 연결 관련
  let ws = null;
  let gameRoomId = null;
  let isHost = false;
  let connectionAttempts = 0;
  let maxConnectionAttempts = 5;
  
  // 연결 상태
  let isConnected = false;
  let waitingMessage = '서버에 연결 중...';
  
  function startGame() {
    if (!playerId.trim()) {
      alert('아이디를 입력해주세요!');
      return;
    }
    
    if (playerId.length < 2) {
      alert('아이디는 2글자 이상 입력해주세요!');
      return;
    }
    
    gamePhase = 'waiting';
    connectToServer();
  }
  
  // WebSocket 서버 연결
  function connectToServer() {
    if (connectionAttempts >= maxConnectionAttempts) {
    waitingMessage = '서버 연결에 실패했습니다. 페이지를 새로고침해주세요.';
    return;
  }
  
  connectionAttempts++;
  waitingMessage = `서버에 연결 중... (${connectionAttempts}/${maxConnectionAttempts})`;
  
  try {
    // Socket.IO 클라이언트 라이브러리 사용
    // HTML head에 다음 스크립트 추가 필요:
    
    const serverUrl = 'http://localhost:3001'; // HTTP 프로토콜 사용
    console.log(`서버 연결 시도: ${serverUrl}/game`);
    
    // Socket.IO 클라이언트로 연결 (네임스페이스 포함)
    ws = io(`${serverUrl}/game`, {
      transports: ['websocket', 'polling'],
      timeout: 10000,
      forceNew: true
    });
    
    ws.on('connect', () => {
      console.log('✅ 서버에 연결되었습니다');
      isConnected = true;
      connectionAttempts = 0;
      waitingMessage = '매칭 대기열에 참가 중...';
      
      // 매칭 요청 전송
      ws.emit('FIND_MATCH', {
        playerId: playerId
      });
    });
    
    ws.on('connection_success', (data) => {
      console.log('연결 성공:', data);
    });
    
    ws.on('MATCH_FOUND', (data) => {
      console.log('매칭 성공:', data);
      opponentId = data.opponentId;
      gameRoomId = data.roomId;
      isHost = data.isHost;
      maxRounds = data.gameInfo?.maxRounds || 10;
      gamePhase = 'playing';
      waitingMessage = `${opponentId}님과 매칭되었습니다!`;
      
      setTimeout(() => {
        waitingMessage = '';
      }, 2000);
    });
    
    ws.on('WAITING_FOR_OPPONENT', (data) => {
      waitingMessage = `상대방을 찾는 중... (대기: ${data.waitingCount || 1}명)`;
    });
    
    ws.on('CHOICE_CONFIRMED', (data) => {
      console.log('선택 확인:', data);
    });
    
    ws.on('OPPONENT_CHOICE_MADE', (data) => {
      opponentReady = true;
      console.log('상대방 선택 완료:', data.message);
    });
    
    ws.on('ROUND_RESULT', (data) => {
      console.log('라운드 결과:', data);
      playerChoice = data.playerChoice;
      opponentChoice = data.opponentChoice;
      playerScore = data.totalPlayerScore;
      opponentScore = data.totalOpponentScore;
      roundResult = data.message;
      round = data.round;
      gamePhase = 'result';
    });
    
    ws.on('NEXT_ROUND_START', (data) => {
      console.log('다음 라운드 시작:', data);
      round = data.round;
      nextRound();
    });
    
    ws.on('GAME_END', (data) => {
      console.log('게임 종료:', data);
      roundResult = data.message;
      gamePhase = 'gameOver';
    });
    
    ws.on('OPPONENT_DISCONNECTED', (data) => {
      alert(`${opponentId}님이 게임을 나갔습니다.`);
      resetGame();
    });
    
    ws.on('GAME_ERROR', (data) => {
      console.error('게임 오류:', data.message);
      alert('게임 오류: ' + data.message);
    });
    
    ws.on('disconnect', (reason) => {
      console.log('서버 연결이 끊어졌습니다:', reason);
      isConnected = false;
      
      if (gamePhase === 'waiting' && connectionAttempts < maxConnectionAttempts) {
        retryConnection();
      }
    });
    
    ws.on('connect_error', (error) => {
      console.error('연결 오류:', error);
      isConnected = false;
      
      if (gamePhase === 'waiting') {
        retryConnection();
      }
    });
    
  } catch (error) {
    console.error('연결 생성 오류:', error);
    retryConnection();
  }
  }
  
  // 서버 메시지 처리
  function handleServerMessage(data) {
    switch (data.type) {
      case 'MATCH_FOUND':
        // 매칭 성공
        opponentId = data.opponentId;
        gameRoomId = data.roomId;
        isHost = data.isHost;
        isConnected = true;
        gamePhase = 'playing';
        waitingMessage = `${opponentId}님과 매칭되었습니다!`;
        
        setTimeout(() => {
          waitingMessage = '';
        }, 2000);
        break;
        
      case 'OPPONENT_CHOICE':
        // 상대방 선택 수신
        opponentChoice = data.choice;
        opponentReady = true;
        
        // 둘 다 선택했으면 결과 계산
        if (playerReady && opponentReady) {
          calculateScores();
          gamePhase = 'result';
          
          setTimeout(() => {
            if (round < maxRounds) {
              nextRound();
            } else {
              endGame();
            }
          }, 4000);
        }
        break;
        
      case 'NEXT_ROUND_START':
        // 다음 라운드 시작 (상대방이 호스트인 경우)
        round = data.round;
        nextRound();
        break;
        
      case 'OPPONENT_DISCONNECTED':
        // 상대방 연결 끊김
        alert(`${opponentId}님이 게임을 나갔습니다.`);
        resetGame();
        break;
        
      case 'GAME_ERROR':
        // 게임 오류
        alert('게임 오류: ' + data.message);
        resetGame();
        break;
        
      case 'WAITING_FOR_OPPONENT':
        waitingMessage = '상대방을 찾는 중...';
        break;
        
      default:
        console.log('알 수 없는 메시지:', data);
    }
  }
  
  function makeChoice(choice) {
    if (gamePhase !== 'playing' || playerReady || !ws) return;
    
    playerChoice = choice;
    playerReady = true;
    
    // 서버에 선택 전송
    ws.send(JSON.stringify({
      type: 'PLAYER_CHOICE',
      roomId: gameRoomId,
      playerId: playerId,
      choice: choice
    }));
  }
  
  function calculateScores() {
    if (playerChoice === 'cooperate' && opponentChoice === 'cooperate') {
      playerScore += 3;
      opponentScore += 3;
      roundResult = '🤝 둘 다 협력! 서로 도움을 주었습니다.';
    } else if (playerChoice === 'cooperate' && opponentChoice === 'defect') {
      playerScore += 0;
      opponentScore += 5;
      roundResult = `😢 ${opponentId}님이 배신! 당신만 손해를 보았습니다.`;
    } else if (playerChoice === 'defect' && opponentChoice === 'cooperate') {
      playerScore += 5;
      opponentScore += 0;
      roundResult = `😈 당신이 배신! ${opponentId}님을 속였습니다.`;
    } else {
      playerScore += 1;
      opponentScore += 1;
      roundResult = '💥 둘 다 배신! 서로 신뢰를 잃었습니다.';
    }
  }
  
  function nextRound() {
    round++;
    playerChoice = '';
    opponentChoice = '';
    playerReady = false;
    opponentReady = false;
    roundResult = '';
    gamePhase = 'playing';
    
    // 서버에 다음 라운드 시작 알림 (호스트만)
    if (ws && isHost) {
      ws.send(JSON.stringify({
        type: 'NEXT_ROUND',
        roomId: gameRoomId,
        round: round
      }));
    }
  }
  
  function endGame() {
    gamePhase = 'gameOver';
    let finalMessage = '';
    
    if (playerScore > opponentScore) {
      finalMessage = `🎉 승리! ${playerId}님이 이겼습니다!`;
    } else if (playerScore < opponentScore) {
      finalMessage = `😭 패배! ${opponentId}님이 이겼습니다.`;
    } else {
      finalMessage = '🤝 무승부! 좋은 게임이었습니다.';
    }
    
    roundResult = finalMessage;
    
    // 서버에 게임 종료 알림
    if (ws) {
      ws.send(JSON.stringify({
        type: 'GAME_END',
        roomId: gameRoomId,
        playerId: playerId,
        finalScore: {
          [playerId]: playerScore,
          [opponentId]: opponentScore
        }
      }));
    }
  }
  
  function resetGame() {
    // WebSocket 연결 종료
    if (ws) {
      if (gameRoomId) {
        ws.send(JSON.stringify({
          type: 'LEAVE_GAME',
          roomId: gameRoomId,
          playerId: playerId
        }));
      }
      ws.close();
      ws = null;
    }
    
    // 게임 상태 초기화
    gamePhase = 'login';
    playerId = '';
    opponentId = '';
    playerScore = 0;
    opponentScore = 0;
    round = 1;
    playerChoice = '';
    opponentChoice = '';
    playerReady = false;
    opponentReady = false;
    roundResult = '';
    isConnected = false;
    waitingMessage = '서버에 연결 중...';
    gameRoomId = null;
    isHost = false;
  }
  
  function cancelMatch() {
    if (ws) {
      ws.send(JSON.stringify({
        type: 'CANCEL_MATCH',
        playerId: playerId
      }));
      ws.close();
      ws = null;
    }
    resetGame();
  }
  
  function getChoiceText(choice) {
    return choice === 'cooperate' ? '🤝 협력' : '💀 배신';
  }
  
  function getChoiceEmoji(choice) {
    return choice === 'cooperate' ? '🤝' : '💀';
  }
  
  onDestroy(() => {
    // WebSocket 연결 정리
    if (ws) {
      if (gameRoomId) {
        ws.send(JSON.stringify({
          type: 'LEAVE_GAME',
          roomId: gameRoomId,
          playerId: playerId
        }));
      }
      ws.close();
    }
  });
</script>

<svelte:head>
  <title>죄수의 딜레마 - 멀티플레이어</title>
  <meta name="description" content="친구와 함께하는 죄수의 딜레마 게임" />
</svelte:head>

<div class="game-container">
  
  {#if gamePhase === 'login'}
    <!-- 로그인 화면 -->
    <div class="login-card">
      <h1 class="login-title">죄수의 딜레마</h1>
      <p class="login-subtitle">멀티플레이어 게임</p>
      
      <div class="login-form">
        <label for="playerId" class="input-label">게임 아이디</label>
        <input 
          id="playerId"
          type="text" 
          bind:value={playerId}
          placeholder="아이디를 입력하세요"
          class="player-input"
          maxlength="10"
          on:keydown={(e) => e.key === 'Enter' && startGame()}
        />
        <button class="btn-start" on:click={startGame}>
          게임 시작
        </button>
      </div>
      
      <div class="game-info">
        <h3>게임 규칙</h3>
        <ul>
          <li>총 {maxRounds}라운드 진행</li>
          <li>협력: 둘 다 3점, 한 명만 0점</li>
          <li>배신: 배신자 5점, 협력자 0점</li>
          <li>둘 다 배신: 각각 1점</li>
        </ul>
      </div>
    </div>
    
  {:else if gamePhase === 'waiting'}
    <!-- 대기 화면 -->
    <div class="waiting-card">
      <h2 class="waiting-title">매칭 중...</h2>
      <div class="spinner"></div>
      <p class="waiting-message">{waitingMessage}</p>
      <p class="player-info">플레이어: <strong>{playerId}</strong></p>
      
      <button class="btn-cancel" on:click={cancelMatch}>
        취소
      </button>
    </div>
    
  {:else}
    <!-- 게임 화면 -->
    
    <!-- 점수판 -->
    <div class="scoreboard-card card-hover">
      <h1 class="scoreboard-title">점수판</h1>
      <div class="players-container">
        <div class="player-section">
          <div class="player-name">{playerId}</div>
          <div class="score-display">{playerScore}</div>
        </div>
        <div class="vs-text">VS</div>
        <div class="player-section">
          <div class="player-name">{opponentId}</div>
          <div class="score-display">{opponentScore}</div>
        </div>
      </div>
      
      {#if gamePhase !== 'gameOver'}
        <div class="round-progress">
          라운드 {round} / {maxRounds}
        </div>
      {/if}
    </div>

    <!-- 라운드 정보 -->
    <div class="round-card card-hover">
      {#if gamePhase === 'playing'}
        <h2 class="round-title">라운드 {round}</h2>
        {#if waitingMessage}
          <p class="round-description">{waitingMessage}</p>
        {:else if !playerReady}
          <p class="round-description">당신의 선택을 기다리고 있습니다...</p>
        {:else if !opponentReady}
          <p class="round-description">{opponentId}님의 선택을 기다리고 있습니다...</p>
          <p class="choice-made">당신의 선택: {getChoiceEmoji(playerChoice)}</p>
        {/if}
      {:else if gamePhase === 'result'}
        <div class="result-fade-in">
          <h2 class="round-title">라운드 {round} 결과</h2>
          <p class="round-description">{roundResult}</p>
          <div class="choices-display">
            <div class="choice-item">
              <span class="choice-player">{playerId}</span>
              <span class="choice-result">{getChoiceText(playerChoice)}</span>
            </div>
            <div class="choice-item">
              <span class="choice-player">{opponentId}</span>
              <span class="choice-result">{getChoiceText(opponentChoice)}</span>
            </div>
          </div>
        </div>
      {:else if gamePhase === 'gameOver'}
        <div class="result-fade-in">
          <h2 class="round-title">게임 종료</h2>
          <p class="round-description">{roundResult}</p>
          <div class="final-scores">
            <div class="final-score-item">
              {playerId}: {playerScore}점
            </div>
            <div class="final-score-item">
              {opponentId}: {opponentScore}점
            </div>
          </div>
        </div>
      {/if}
    </div>

    <!-- 선택 영역 -->
    {#if gamePhase === 'playing' && !playerReady && !waitingMessage}
      <div class="choice-card">
        <h3 class="choice-title">당신의 선택은?</h3>
        <div class="choice-buttons">
          <button 
            class="btn-cooperate choice-animation" 
            on:click={() => makeChoice('cooperate')}
          >
            <span class="btn-main-text">🤝 협력하기</span>
            <span class="btn-sub-text">상대방을 믿고 협력</span>
          </button>
          
          <button 
            class="btn-defect choice-animation" 
            on:click={() => makeChoice('defect')}
          >
            <span class="btn-main-text">💀 배신하기</span>
            <span class="btn-sub-text">자신의 이익을 우선</span>
          </button>
        </div>
      </div>
    {/if}

    <!-- 게임 종료 후 버튼 -->
    {#if gamePhase === 'gameOver'}
      <div style="text-align: center; margin-top: 1rem;">
        <button class="btn-start" on:click={resetGame}>
          새 게임 시작
        </button>
      </div>
    {/if}
  {/if}
</div>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
  }
</style>