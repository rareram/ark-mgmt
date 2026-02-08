#!/usr/bin/env python3
"""
Jira Web Scraper using Playwright
로그인해서 Jira 이슈 데이터를 자동으로 수집
"""

import asyncio
import json
import os
import sys
from datetime import datetime
from dotenv import load_dotenv
from playwright.async_api import async_playwright
from playwright_stealth import stealth

# .env 로드
current_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(current_dir, ".env"))

# 설정
JIRA_URL = os.getenv("JIRA_URL", "https://lab.idatabank.com/jira")
JIRA_USERNAME = os.getenv("JIRA_USERNAME")
JIRA_PASSWORD = os.getenv("JIRA_PASSWORD")

# 세션 저장 경로
SESSION_DIR = os.path.join(current_dir, ".sessions")

# 출력 경로 설정
PROJECT_ROOT = os.path.abspath(os.path.join(current_dir, "..", ".."))
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "issues")

async def scrape_issue(issue_key, headless=True):
    if not JIRA_USERNAME or not JIRA_PASSWORD:
        print("에러: JIRA_USERNAME 또는 JIRA_PASSWORD가 .env 파일에 설정되지 않았습니다.")
        return

    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {issue_key} 수집 시작 (headless={headless})...")

    os.makedirs(SESSION_DIR, exist_ok=True)

    async with async_playwright() as p:
        # persistent_context를 사용하여 세션 유지 (로그인 상태 및 쿠키 저장)
        context = await p.chromium.launch_persistent_context(
            user_data_dir=SESSION_DIR,
            headless=headless,
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        )
        page = await context.new_page()
        
        # stealth 적용 (stealth 모듈 자체가 callable이 아닐 경우를 대비해 처리)
        try:
            if callable(stealth):
                await stealth(page)
            elif hasattr(stealth, 'stealth') and callable(stealth.stealth):
                await stealth.stealth(page)
        except Exception as e:
            print(f"Stealth 적용 중 경고 (무시 가능): {e}")

        # 1. 이슈 페이지 바로 접속 시도 (세션이 살아있으면 바로 보임)
        issue_url = f"{JIRA_URL}/browse/{issue_key}"
        await page.goto(issue_url)
        await page.wait_for_load_state("networkidle")

        # 로그인 페이지로 리다이렉트 되었는지 확인
        if "login.jsp" in page.url or await page.query_selector("#login-form-username"):
            print("로그인이 필요합니다. 로그인을 시도합니다...")
            await page.fill("#login-form-username", JIRA_USERNAME)
            await page.fill("#login-form-password", JIRA_PASSWORD)
            await page.click("#login-form-submit")
            await page.wait_for_load_state("networkidle")
            
            # 로그인 후 다시 이슈 페이지로 이동 (혹시 모르니)
            if issue_url not in page.url:
                await page.goto(issue_url)
                await page.wait_for_load_state("networkidle")

        # 캡챠 체크
        if await page.query_selector(".captcha-image") or "captcha" in await page.content():
            print("!!! 경고: 캡챠가 감지되었습니다 !!!")
            if headless:
                print("Headless 모드에서는 캡챠를 해결할 수 없습니다.")
                print("브라우저를 띄워 직접 로그인하려면 다음을 실행하세요:")
                print(f"uv run {os.path.join('03_playwright_scraper', 'jira_playwright_scraper.py')} {issue_key} --no-headless")
                await context.close()
                return
            else:
                print("브라우저에서 캡챠를 해결하고 로그인을 완료해주세요. (60초 대기 중...)")
                try:
                    # 사용자가 로그인할 때까지 대기 (이슈 요약 요소가 보일 때까지)
                    await page.wait_for_selector("#summary-val", timeout=60000)
                except:
                    print("대기 시간 초과.")
                    await context.close()
                    return

        # 2. 데이터 추출
        try:
            # 기본 정보가 로드될 때까지 대기
            await page.wait_for_selector("#summary-val", timeout=10000)
            
            summary = await page.inner_text("#summary-val")
            status = await page.inner_text("#status-val") if await page.query_selector("#status-val") else ""
            priority = await page.inner_text("#priority-val") if await page.query_selector("#priority-val") else ""
            
            description_elem = await page.query_selector("#description-val")
            description = await description_elem.inner_text() if description_elem else ""
            
            comments = []
            comment_elements = await page.query_selector_all(".activity-comment")
            for elem in comment_elements:
                author_elem = await elem.query_selector(".author")
                time_elem = await elem.query_selector("time")
                body_elem = await elem.query_selector(".action-body")
                
                comments.append({
                    "author": await author_elem.inner_text() if author_elem else "Unknown",
                    "time": await time_elem.get_attribute("datetime") if time_elem else "",
                    "body": await body_elem.inner_text() if body_elem else ""
                })

            issue_data = {
                "issue_key": issue_key,
                "url": issue_url,
                "summary": summary.strip(),
                "status": status.strip(),
                "priority": priority.strip(),
                "description": description.strip(),
                "comments": comments,
                "scraped_at": datetime.now().isoformat()
            }

            # 3. 저장
            os.makedirs(OUTPUT_DIR, exist_ok=True)
            filename = f"{datetime.now().strftime('%Y-%m-%d')}-{issue_key}-scraped.json"
            filepath = os.path.join(OUTPUT_DIR, filename)
            
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(issue_data, f, ensure_ascii=False, indent=2)
            
            print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 저장 완료: {filepath}")

        except Exception as e:
            print(f"데이터 추출 중 에러 발생: {e}")
            await page.screenshot(path=f"error_{issue_key}.png")

        await context.close()

async def main():
    if len(sys.argv) < 2:
        print("사용법: uv run jira_playwright_scraper.py <ISSUE_KEY> [--no-headless]")
        sys.exit(1)
    
    issue_key = sys.argv[1]
    headless = "--no-headless" not in sys.argv
    
    await scrape_issue(issue_key, headless=headless)

if __name__ == "__main__":
    asyncio.run(main())