package oit.is.inudaisuki.springboot_samples.service;

import java.io.IOException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Service
public class AsyncCount58 {

  private final AtomicInteger customerCount = new AtomicInteger(1);// customerロール用カウンター
  private final AtomicInteger sellerCount = new AtomicInteger(1);// sellerロール用カウンター
  private final Logger logger = LoggerFactory.getLogger(AsyncCount58.class);

  /**
   *
   * @param emitter
   * @param role    "CUSTOMER" "SELLER"のいずれかを想定している
   */
  @Async
  public void startCount(SseEmitter emitter, String role) {
    AtomicBoolean active = new AtomicBoolean(true);
    emitter.onCompletion(() -> active.set(false));
    emitter.onTimeout(() -> active.set(false));
    emitter.onError(error -> active.set(false));
    count(emitter, role, active);
  }

  /**
   * 接続中だけ1秒ごとに数値を送る。@Asyncを付けることで、Controllerを待たせずに
   * 送信処理を続けられる。
   */
  private void count(SseEmitter emitter, String role, AtomicBoolean active) {
    logger.info("AsyncCount58.count");
    try {
      while (active.get()) {
        int counter;
        // CUSTOMERとSELLERでカウンタを分ける。
        // それ以外の認証済みユーザには、サンプルとして常に0を送る。
        if (role.equals("CUSTOMER")) {
          counter = customerCount.getAndIncrement();
        } else if (role.equals("SELLER")) {
          counter = sellerCount.getAndIncrement();
        } else {
          counter = 0;
        }
        // ロールごとのカウンタとロール名を送る
        emitter.send(SseEmitter.event()
            .data(counter)
            .id(role));
        TimeUnit.SECONDS.sleep(1);
      }
    } catch (IOException e) {
      // ブラウザが閉じられるとsendで例外になるため、その時点で処理を終える。
      logger.debug("SSE connection was closed: {}", e.getMessage());
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    } finally {
      active.set(false);
      emitter.complete();
    }
  }
}
