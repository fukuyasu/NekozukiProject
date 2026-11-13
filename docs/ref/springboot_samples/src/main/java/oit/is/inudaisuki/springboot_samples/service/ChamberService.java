package oit.is.inudaisuki.springboot_samples.service;

import java.util.ArrayList;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import oit.is.inudaisuki.springboot_samples.model.Chamber;
import oit.is.inudaisuki.springboot_samples.model.ChamberMapper;
import oit.is.inudaisuki.springboot_samples.model.ChamberUser;
import oit.is.inudaisuki.springboot_samples.model.UserInfo;

/**
 * 小部屋と利用者情報に関するDB操作をまとめるService。
 * Controllerは画面の入出力、Serviceは処理とDB操作、という役割に分けている。
 */
@Service
public class ChamberService {
  private final ChamberMapper chamberMapper;

  public ChamberService(ChamberMapper chamberMapper) {
    this.chamberMapper = chamberMapper;
  }

  @Transactional(readOnly = true)
  public Chamber findChamberById(int id) {
    return chamberMapper.selectById(id);
  }

  @Transactional
  public void addChamber(Chamber chamber) {
    chamberMapper.insertChamber(chamber);
  }

  @Transactional(readOnly = true)
  public ArrayList<Chamber> findChambersByName(String chamberName) {
    return chamberMapper.selectAllByChamberName(chamberName);
  }

  @Transactional(readOnly = true)
  public ArrayList<ChamberUser> findChamberUsers() {
    return chamberMapper.selectAllChamberUser();
  }

  /**
   * 利用者情報を追加して、画面表示用の一覧を返す。
   * 途中で例外が起きた場合は、このメソッド全体をロールバックする。
   */
  @Transactional
  public ArrayList<ChamberUser> addUserInfoAndFindChamberUsers(UserInfo userInfo) {
    chamberMapper.insertUserInfo(userInfo);
    return chamberMapper.selectAllChamberUser();
  }
}
