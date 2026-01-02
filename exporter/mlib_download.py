import os
import queue
from concurrent.futures import ThreadPoolExecutor
from playwright.sync_api import sync_playwright

task_list = []

def pdf_worker(worker_id: int, task_queue: queue.Queue):
    print(f"[Worker-{worker_id}] 启动")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True, args=["--no-sandbox", "--disable-setuid-sandbox"])
        context = browser.new_context()

        processed_count = 0
        while True:
            if processed_count > 0 and processed_count % 100 == 0:
                context.close()
                context = browser.new_context()
                
            task = task_queue.get()
            if task is None:
                break

            url, final_path = task
            if os.path.exists(final_path):
                os.remove(final_path)

            target_dir = os.path.dirname(final_path)
            if not os.path.exists(target_dir):
                os.makedirs(target_dir, exist_ok=True)
            
            print(f'[Worker-{worker_id}] 正在下载 {final_path} 从 {url}')
    
            page = context.new_page()
            page.goto(url, wait_until="load")

            page.evaluate("""
                () => Promise.all([
                    document.fonts.ready,
                    new Promise(resolve => {
                        if (document.readyState === 'complete') resolve();
                        else window.addEventListener('load', resolve);
                    }),
                    new Promise(resolve => {
                        requestAnimationFrame(() => {
                            requestAnimationFrame(resolve);
                        });
                    })
                ])
            """)

            page.pdf(
                path=final_path,
                format="A4",
                margin={"top": "25.5mm", "bottom": "25.5mm", "left": "19mm", "right": "19mm"},
                print_background=True,
            )

            page.close()

            processed_count += 1
            task_queue.task_done()

        context.close()
        browser.close()
        
        print(f"[Worker-{worker_id}] 完成。")

def add_task(task):
    task_list.append(task)

def start_tasks(max_threads: int = int(os.getenv('MAX_THREADS', 4))):
    print(f"--- 任务开始: 共 {len(task_list)} 个 URL，最大并发数 {max_threads} ---")
    task_queue = queue.Queue()
    for item in task_list:
        if os.path.exists(item[1]):
            os.remove(item[1])
        task_queue.put(item)
    with ThreadPoolExecutor(max_workers=max_threads) as executor:
        for i in range(max_threads):
            executor.submit(pdf_worker, i, task_queue)
        task_queue.join()
        for _ in range(max_threads):
            task_queue.put(None)
    print("--- 所有任务完成 ---")
