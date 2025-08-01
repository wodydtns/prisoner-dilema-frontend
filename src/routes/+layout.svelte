<script>
  import '../app.css';
  import { onMount } from 'svelte';
  
  // 페이지 로드 시 초기화
  onMount(() => {
    console.log('죄수의 딜레마 게임이 시작됩니다!');
  });
</script>

<div class="min-h-screen">
  <header class="bg-white/10 backdrop-blur-md shadow-lg sticky top-0 z-50">
    <div class="container mx-auto px-4 py-4">
      <h1 class="text-2xl font-bold text-gray-800 text-center">
        🎮 죄수의 딜레마 시뮬레이터
      </h1>
    </div>
  </header>
  
  <main class="container mx-auto px-4 py-8">
    <slot />
  </main>
  
  <footer class="bg-gray-800 text-white py-6 mt-16">
    <div class="container mx-auto px-4 text-center">
      <p>&copy; 2025 죄수의 딜레마 게임. 협력과 배신의 선택을 경험해보세요.</p>
    </div>
  </footer>
</div>
