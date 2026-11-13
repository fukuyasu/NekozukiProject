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

import oit.is.inudaisuki.springboot_samples.model.Fruit;

@Service
public class AsyncCountFruit56 {
  private final AtomicInteger count = new AtomicInteger(1);
  private final Logger logger = LoggerFactory.getLogger(AsyncCountFruit56.class);

  /**
   * SSE接続を開始する。接続が終了したことをactiveで共有し、非同期処理が
   * いつまでも動き続けないようにする。
   *
   * @param emitter ブラウザへ送信するためのオブジェクト
   */
  @Async
  public void startCount(SseEmitter emitter) {
    AtomicBoolean active = new AtomicBoolean(true);
    emitter.onCompletion(() -> active.set(false));
    emitter.onTimeout(() -> active.set(false));
    emitter.onError(error -> active.set(false));
    count(emitter, active);
  }

  private void count(SseEmitter emitter, AtomicBoolean active) {
    logger.info("count start");
    try {
      while (active.get()) {
        int currentCount = count.getAndIncrement();
        logger.info("send:{}", currentCount);
        // sendによってcountがブラウザにpushされる
        emitter.send(currentCount);
        // 1秒STOP
        TimeUnit.SECONDS.sleep(1);
      }
    } catch (IOException e) {
      // ブラウザを閉じた場合など、送信に失敗したら処理を終了する
      logger.debug("SSE connection was closed: {}", e.getMessage());
    } catch (InterruptedException e) {
      // スレッドを停止する指示を受けた場合は、割り込み状態を元に戻して終了する
      Thread.currentThread().interrupt();
    } finally {
      active.set(false);
      emitter.complete();
    }
  }

  @Async
  public void pushFruit(SseEmitter emitter) {
    logger.info("pushFruit start");
    AtomicBoolean active = new AtomicBoolean(true);
    emitter.onCompletion(() -> active.set(false));
    emitter.onTimeout(() -> active.set(false));
    emitter.onError(error -> active.set(false));

    Fruit fruit = new Fruit();
    fruit.setName("桃");
    fruit.setPrice(300);
    // 10回sendすると一度接続を終了する．その後ブラウザを開いていればブラウザから自動的に再接続されてまた10回sendされる（以降繰り返し）
    for (int i = 0; i < 10 && active.get(); i++) {
      try {
        logger.info("send(fruit)");
        TimeUnit.SECONDS.sleep(1);// 1秒STOP
        // fruitのJSONオブジェクトがクライアントに送付される
        emitter.send(fruit);

      } catch (IOException e) {
        // ブラウザを閉じた場合は送信を終了する
        logger.debug("SSE connection was closed: {}", e.getMessage());
        break;
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        // 例外が発生したらカウントとsendを終了する
        break;
      }
    }
    emitter.complete();// emitterの後始末．明示的にブラウザとの接続を一度切る．
  }
}
