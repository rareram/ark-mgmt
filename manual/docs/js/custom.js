/*
  이 파일에 사용자 정의 JavaScript를 추가할 수 있습니다.
  mkdocs.yml의 extra_javascript 설정에 의해 자동으로 포함됩니다.

  예시:
  document.addEventListener('DOMContentLoaded', (event) => {
    console.log('Custom JS Loaded');
  });
*/

document.addEventListener('DOMContentLoaded', function() {
  // Material for MkDocs 테마의 메인 콘텐츠 영역인 .md-content 내부의 모든 링크를 선택합니다.
  var links = document.querySelectorAll('.md-content a');

  links.forEach(function(link) {
    // 링크의 href 속성이 있고, http:// 또는 https:// 로 시작하는 외부 링크인지 확인합니다.
    if (link.href && (link.protocol === 'http:' || link.protocol === 'https:' ) && link.hostname !== window.location.hostname) {
      // 새 탭에서 열리도록 target 속성을 설정합니다.
      link.setAttribute('target', '_blank');
      // 보안 및 SEO를 위해 rel 속성을 'noopener noreferrer'로 설정합니다.
      link.setAttribute('rel', 'noopener noreferrer');
    }
  });
});