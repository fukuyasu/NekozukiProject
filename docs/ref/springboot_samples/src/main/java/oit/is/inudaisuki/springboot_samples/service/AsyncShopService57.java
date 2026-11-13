package oit.is.inudaisuki.springboot_samples.service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import oit.is.inudaisuki.springboot_samples.model.Fruit;
import oit.is.inudaisuki.springboot_samples.model.FruitMapper;

@Service
public class AsyncShopService57 {
  private final Logger logger = LoggerFactory.getLogger(AsyncShopService57.class);
  private final FruitMapper fMapper;

  /*
   * 接続中のブラウザだけを保存する。ConcurrentHashMapを使うと、SSEの送信処理と
   * 接続終了処理が同時に動いても安全に扱える。
   */
  private final ConcurrentHashMap<String, SseEmitter> emitters = new ConcurrentHashMap<>();

  public AsyncShopService57(FruitMapper fMapper) {
    this.fMapper = fMapper;
  }

  /**
   * 購入対象の果物IDの果物をDBから削除し，購入対象の果物オブジェクトを返す
   *
   * @param id 購入対象の果物のID
   * @return 購入対象の果物のオブジェクトを返す
   */
  @Transactional
  public Fruit deleteFruit(int id) {
    // 削除対象のフルーツを取得
    Fruit fruit = fMapper.selectById(id);

    // 削除
    fMapper.deleteById(id);

    return fruit;
  }

  @Transactional(readOnly = true)
  public ArrayList<Fruit> syncShowFruitsList() {
    return fMapper.selectAllFruit();
  }

  @Transactional(readOnly = true)
  public Fruit findFruitById(int id) {
    return fMapper.selectById(id);
  }

  /**
   * フルーツの情報を更新する。トランザクションはControllerではなく、DBを操作する
   * Serviceで開始する。
   *
   * @param fruit 更新するフルーツ
   */
  @Transactional
  public void updateFruit(Fruit fruit) {
    fMapper.updateById(fruit);
  }

  /**
   * SSE接続を1つ追加し、現在のフルーツ一覧を直ちに送る。
   *
   * @return ブラウザへ返すSSE接続
   */
  public SseEmitter subscribeFruits() {
    SseEmitter emitter = new SseEmitter(60000L);
    String emitterId = UUID.randomUUID().toString();
    emitters.put(emitterId, emitter);

    // ブラウザが閉じられた接続は必ずMapから取り除く。
    emitter.onCompletion(() -> emitters.remove(emitterId));
    emitter.onTimeout(() -> emitters.remove(emitterId));
    emitter.onError(error -> emitters.remove(emitterId));

    sendFruits(emitterId, emitter);
    return emitter;
  }

  /**
   * DB更新後に、接続中のすべてのブラウザへ新しい一覧を送る。
   * ControllerはDB更新が完了した後にこのメソッドを呼ぶ。
   */
  public void notifyFruitsUpdated() {
    emitters.forEach(this::sendFruits);
  }

  private void sendFruits(String emitterId, SseEmitter emitter) {
    try {
      emitter.send(syncShowFruitsList());
    } catch (IOException e) {
      // 送信できない接続は保持し続けず、次回以降の通知対象から外す。
      logger.debug("SSE connection was closed: {}", e.getMessage());
      emitters.remove(emitterId);
      emitter.completeWithError(e);
    }
  }

}
