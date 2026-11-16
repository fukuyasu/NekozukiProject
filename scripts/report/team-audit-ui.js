(() => {
  'use strict';
  const data = JSON.parse(document.getElementById('audit-data').textContent);
  const $ = id => document.getElementById(id);
  const issueMap = new Map(data.issues.map(item => [item.number, item]));
  const prMap = new Map(data.prs.map(item => [item.number, item]));
  const commitMap = new Map(data.mainCommits.map(item => [item.sha, item]));
  const allIssueNumbers = new Set(data.allIssueNumbers);
  let visibleIssues = [], visiblePrs = [];
  let closedIssues = [], closedPrs = [], openIssues = [], openPrs = [];

  function el(tag, text, className) {
    const node = document.createElement(tag);
    if (text != null) node.textContent = String(text);
    if (className) node.className = className;
    return node;
  }
  function append(parent, ...children) {
    for (const child of children) parent.append(child);
    return parent;
  }
  function date(value) {
    if (!value) return '—';
    const time = Date.parse(value);
    return Number.isFinite(time) ? new Intl.DateTimeFormat('ja-JP', {
      timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit'
    }).format(time) : value;
  }
  function elapsed(start, end) {
    const ms = Date.parse(end) - Date.parse(start);
    if (!Number.isFinite(ms) || ms < 0) return '算出不可';
    const hours = Math.floor(ms / 3600000);
    return `${Math.floor(hours / 24)}日 ${hours % 24}時間`;
  }
  function milestone(item) { return item.milestone?.title || '未設定'; }
  function assignees(item) { return (item.assignees || []).map(user => user.login).filter(Boolean); }
  function owner(pr) { return assignees(pr)[0] || pr.user?.login || '未設定'; }
  function unique(values) { return [...new Set(values)]; }
  function relatedNumbers(pr) {
    const body = pr.body || '';
    const heading = /^## 関連Issue\s*$/m.exec(body);
    if (!heading) return [];
    const after = body.slice(heading.index + heading[0].length).split(/^## /m)[0];
    return unique([...after.matchAll(/#(\d+)/g)].map(match => Number(match[1]))).filter(number => allIssueNumbers.has(number));
  }
  function link(kind, item, label) {
    const a = el('a', label || `#${item.number}`);
    a.href = item.html_url;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.dataset.kind = kind;
    a.dataset.number = item.number;
    return a;
  }
  function numberLink(kind, number) {
    const item = (kind === 'issue' ? issueMap : prMap).get(number);
    if (item) return link(kind, item);
    return el('span', `#${number}（表示対象外）`);
  }
  function table(headers, rows) {
    if (!rows.length) return el('p', '該当項目はありません。', 'empty');
    const t = el('table');
    const head = el('thead'), headRow = el('tr');
    headers.forEach(name => headRow.append(el('th', name)));
    head.append(headRow); t.append(head);
    const body = el('tbody');
    for (const cells of rows) {
      const row = el('tr');
      for (const cell of cells) {
        const td = el('td');
        if (cell instanceof Node) td.append(cell);
        else td.textContent = cell == null ? '—' : String(cell);
        row.append(td);
      }
      body.append(row);
    }
    t.append(body);
    return t;
  }
  function joinedLinks(kind, numbers) {
    const span = el('span');
    numbers.forEach((number, index) => {
      if (index) span.append('、');
      span.append(numberLink(kind, number));
    });
    if (!numbers.length) span.textContent = '—';
    return span;
  }
  function sectionText(body, title) {
    const found = new RegExp(`^## ${title}\\s*$`, 'm').exec(body || '');
    return found ? body.slice(found.index + found[0].length).split(/^## /m)[0].trim() : '';
  }
  function detail(body) {
    const details = el('details');
    details.append(el('summary', '本文を表示'), el('div', body || '本文なし', 'body'));
    return details;
  }
  function acStatus(issue) {
    const body = issue.body || '';
    const heading = /^#{2,3}\s*AC(?:（受け入れ基準）)?\s*$/im.exec(body);
    if (!heading) return 'なし';
    const content = body.slice(heading.index + heading[0].length).split(/^#{1,3}\s+/m)[0].trim();
    return content ? 'あり' : 'なし';
  }
  function relatedPrNumbers(issue) {
    return visiblePrs.filter(pr => relatedNumbers(pr).includes(issue.number)).map(pr => pr.number);
  }
  function reviewHistory(pr) {
    const reviews = el('div');
    (pr.reviews || []).forEach((review, index) => {
      if (index) reviews.append(el('br'));
      reviews.append(`${review.user || '不明'}: ${review.state} (${date(review.submitted_at)})`);
    });
    if (!pr.reviews?.length) reviews.textContent = '—';
    return reviews;
  }
  function branchText(pr) {
    return `${pr.head?.ref || '不明'} → ${pr.base?.ref || '不明'}`;
  }
  function memberCounts(member) {
    const ownedPrs = closedPrs.filter(pr => owner(pr) === member);
    return {
      assignedIssues: closedIssues.filter(issue => assignees(issue).includes(member)).length,
      ownedPrs: ownedPrs.length,
      linkedPrs: ownedPrs.filter(pr => relatedNumbers(pr).length > 0).length,
      reviewedPrs: closedPrs.filter(pr => owner(pr) !== member && pr.reviews.some(review => review.user === member && review.submitted_at)).length,
      mergedPrs: closedPrs.filter(pr => owner(pr) !== member && pr.mergedBy === member).length
    };
  }
  function renderMembers() {
    const rows = data.members.map(member => {
      const counts = memberCounts(member);
      return [member, counts.assignedIssues, counts.ownedPrs, counts.linkedPrs, counts.reviewedPrs, counts.mergedPrs];
    });
    $('members').replaceChildren(table(['メンバー', '担当Issue', '担当PR', '関連Issueのある担当PR', '他者PRのレビュー', '他者PRのマージ'], rows));
  }
  function spreadsheetCell(value) {
    const cleaned = String(value ?? '').replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, ' ').trim();
    return /^[=+\-@]/.test(cleaned) ? `'${cleaned}` : cleaned;
  }
  function spreadsheetDate(value) {
    if (!value) return '';
    const timestamp = Date.parse(value);
    if (!Number.isFinite(timestamp)) return '';
    const jst = new Date(timestamp + 9 * 60 * 60 * 1000);
    const two = n => String(n).padStart(2, '0');
    return `${jst.getUTCFullYear()}/${two(jst.getUTCMonth() + 1)}/${two(jst.getUTCDate())} ${two(jst.getUTCHours())}:${two(jst.getUTCMinutes())}`;
  }
  function spreadsheetDuration(start, end) {
    const minutes = Math.floor((Date.parse(end) - Date.parse(start)) / 60000);
    if (!Number.isFinite(minutes) || minutes < 0) return '';
    return `${Math.floor(minutes / 1440)}日 ${Math.floor(minutes % 1440 / 60)}時間 ${minutes % 60}分`;
  }
  function spreadsheetTsv() {
    const scope = $('filter').value === 'all' ? `${data.milestones.join('・')}＋未設定` : $('filter').value;
    const lines = [];
    const add = values => lines.push(values.map(spreadsheetCell).join('\t'));
    const startTable = (title, headers) => {
      if (lines.length) lines.push('');
      add([`${title}（${scope}）`]);
      add(headers);
    };

    startTable('集計', ['区分', 'メンバー', 'Issue数', 'PR数', '関連IssueありPR', '他者レビュー', '他者マージ']);
    for (const member of data.members) {
      const counts = memberCounts(member);
      add(['メンバー（Close済み）', member, counts.assignedIssues, counts.ownedPrs,
        counts.linkedPrs, counts.reviewedPrs, counts.mergedPrs]);
    }
    add(['全体（Close済み）', '', closedIssues.length, closedPrs.length, '', '', '']);
    add(['全体（未Close）', '', openIssues.length, openPrs.length, '', '', '']);

    startTable('PR', ['番号', '状態', 'Milestone', 'タイトル', 'GitHub URL', '担当者', '作成者',
      '作成日時（日本時間）', '終了日時（日本時間）', 'マージ者', '所要時間', '関連Issue',
      'レビュー履歴', 'ブランチ', '変更内容有無', 'AC確認結果有無']);
    for (const pr of [...closedPrs, ...openPrs]) {
      const state = pr.merged_at ? 'マージ済み' : pr.closed_at ? 'Close済み・未マージ' : '未Close';
      const reviews = (pr.reviews || []).map(review => `${review.user || '不明'} ${review.state} ${spreadsheetDate(review.submitted_at)}`).join('；');
      add([pr.number, state, milestone(pr), pr.title, pr.html_url, owner(pr), pr.user?.login,
        spreadsheetDate(pr.created_at), spreadsheetDate(pr.merged_at || pr.closed_at), pr.mergedBy,
        pr.closed_at ? spreadsheetDuration(pr.created_at, pr.merged_at || pr.closed_at) : '',
        relatedNumbers(pr).map(number => `Issue #${number}`).join('、'), reviews,
        branchText(pr), sectionText(pr.body, '変更内容') ? 'あり' : 'なし',
        sectionText(pr.body, 'AC確認結果') ? 'あり' : 'なし']);
    }

    startTable('Issue', ['番号', '状態', 'Milestone', 'タイトル', 'GitHub URL', '担当者', '作成者',
      '作成日時（日本時間）', 'Close日時（日本時間）', '所要時間', '関連PR', 'Close元PR', 'AC有無']);
    for (const issue of [...closedIssues, ...openIssues]) {
      add([issue.number, issue.closed_at ? 'Close済み' : '未Close', milestone(issue),
        issue.title, issue.html_url, assignees(issue).join('、') || '未設定', issue.user?.login,
        spreadsheetDate(issue.created_at), spreadsheetDate(issue.closed_at),
        issue.closed_at ? spreadsheetDuration(issue.created_at, issue.closed_at) : '',
        relatedPrNumbers(issue).map(number => `PR #${number}`).join('、'),
        issue.closedByPr ? `PR #${issue.closedByPr}` : '', acStatus(issue)]);
    }
    return lines.join('\n');
  }
  async function copyOverview() {
    const value = spreadsheetTsv();
    const status = $('copy-status');
    const fallback = $('copy-fallback');
    fallback.hidden = true;
    fallback.value = '';
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard API unavailable');
      await navigator.clipboard.writeText(value);
      status.textContent = 'タブ区切りの概要をコピーしました。';
      return;
    } catch (_) {
      fallback.value = value;
      fallback.hidden = false;
      fallback.focus();
      fallback.select();
      try {
        if (document.execCommand?.('copy')) {
          fallback.hidden = true;
          status.textContent = 'タブ区切りの概要をコピーしました。';
          return;
        }
      } catch (_) { /* 手動コピーへ進む */ }
      status.textContent = '自動コピーできませんでした。表示されたデータを選択してコピーしてください。';
      fallback.focus();
      fallback.select();
    }
  }
  function renderDurations() {
    const items = [
      ...closedIssues.map(item => ({kind: 'issue', item, start: item.created_at, end: item.closed_at, endLabel: 'Close'})),
      ...closedPrs.map(item => ({kind: 'pr', item, start: item.created_at, end: item.merged_at || item.closed_at, endLabel: item.merged_at ? 'マージ' : 'Close'}))
    ];
    items.sort((a, b) => (Date.parse(b.end) - Date.parse(b.start)) - (Date.parse(a.end) - Date.parse(a.start)));
    $('durations').replaceChildren(table(['種類', '項目', '開始（作成）', '終了', '経過時間'], items.map(({kind, item, start, end, endLabel}) => [
      kind === 'issue' ? 'Issue' : 'PR', link(kind, item, `#${item.number} ${item.title}`), date(start), `${date(end)}（${endLabel}）`, elapsed(start, end)
    ])));
  }
  function renderIssues() {
    const rows = closedIssues.map(issue => {
      const body = append(el('div'), detail(issue.body), el('div', `作成: ${date(issue.created_at)} / Close: ${date(issue.closed_at)}`, 'muted'));
      return [link('issue', issue, `#${issue.number} ${issue.title}`), milestone(issue), assignees(issue).join('、') || '未設定', issue.state, acStatus(issue), joinedLinks('pr', relatedPrNumbers(issue)), issue.closedByPr ? numberLink('pr', issue.closedByPr) : 'PRによるClose記録なし', body];
    });
    $('issues').replaceChildren(table(['Issue', 'Milestone', '担当者', '状態', 'AC', '関連PR', 'Close元', '詳細'], rows));
  }
  function renderPrs() {
    const rows = closedPrs.map(pr => {
      const details = el('div');
      const sections = ['関連Issue', '変更内容', 'AC確認結果', 'テスト結果'];
      for (const name of sections) {
        const value = sectionText(pr.body, name);
        details.append(el('div', `${name}: ${value ? value.slice(0, 100) : '空欄または見出しなし'}`, 'muted'));
      }
      details.append(detail(pr.body));
      const first = pr.firstCommit?.sha ? `最初のコミット ${pr.firstCommit.sha.slice(0, 10)} / 親 ${pr.firstCommit.parents.join('、') || 'なし'}` : '最初のコミットを取得できません';
      details.append(el('div', `base: ${pr.base?.ref || '不明'} / ${first}`, 'muted'));
      details.append(el('div', `作成: ${date(pr.created_at)} / マージ: ${date(pr.merged_at)} / Close: ${date(pr.closed_at)}`, 'muted'));
      return [link('pr', pr, `#${pr.number} ${pr.title}`), milestone(pr), owner(pr), pr.user?.login || '不明', joinedLinks('issue', relatedNumbers(pr)), reviewHistory(pr), pr.mergedBy || '—', details];
    });
    $('prs').replaceChildren(table(['PR', 'Milestone', '担当者', '作成者', '関連Issue', 'レビュー履歴', 'マージ者', '本文・ブランチ'], rows));
  }
  function renderOpenIssues() {
    const rows = openIssues.map(issue => [
      link('issue', issue, `#${issue.number} ${issue.title}`), milestone(issue),
      assignees(issue).join('、') || '未設定', acStatus(issue),
      joinedLinks('pr', relatedPrNumbers(issue)), date(issue.created_at), detail(issue.body)
    ]);
    $('open-issues').replaceChildren(table(['Issue・タイトル', 'Milestone', '担当者', 'AC有無', '関連PR', '開始（作成）', '詳細'], rows));
  }
  function renderOpenPrs() {
    const rows = openPrs.map(pr => [
      link('pr', pr, `#${pr.number} ${pr.title}`), milestone(pr), owner(pr),
      pr.user?.login || '不明', joinedLinks('issue', relatedNumbers(pr)),
      reviewHistory(pr), pr.mergedBy || '—', date(pr.created_at), branchText(pr), detail(pr.body)
    ]);
    $('open-prs').replaceChildren(table(['PR・タイトル', 'Milestone', '担当者', '作成者', '関連Issue', 'レビュー履歴', 'マージ者', '開始（作成）', 'ブランチ', '本文'], rows));
  }
  function renderCommits() {
    $('history-note').textContent = data.historySince
      ? `表示期間: ${date(data.historySince)}以降のmainの第一親履歴です。PR関連付けのないコミットも表示します。誤操作の振り返りへの言及は別途照合してください。`
      : '対象Issue・PRがないため、履歴の期間を設定できません。';
    const visibleNumbers = new Set(visiblePrs.map(pr => pr.number));
    const firstParent = [];
    const seen = new Set();
    let sha = data.mainCommits[0]?.sha;
    while (sha && commitMap.has(sha) && !seen.has(sha)) {
      seen.add(sha);
      const commit = commitMap.get(sha);
      firstParent.push(commit);
      sha = commit.parentShas[0];
    }
    const rows = firstParent.filter(commit => !commit.associatedPrs.length || commit.associatedPrs.some(pr => visibleNumbers.has(pr.number))).map(commit => {
      const a = el('a', commit.sha.slice(0, 10));
      a.href = commit.html_url; a.target = '_blank'; a.rel = 'noopener noreferrer';
      a.dataset.kind = 'commit'; a.dataset.sha = commit.sha;
      return [a, commit.message.split('\n')[0], commit.author, date(commit.date), joinedLinks('pr', commit.associatedPrs.filter(pr => visibleNumbers.has(pr.number)).map(pr => pr.number))];
    });
    $('commits').replaceChildren(table(['SHA', 'メッセージ', '作成者', '日時', '関連PR'], rows));
  }
  function render() {
    const selected = $('filter').value;
    const include = item => selected === 'all' || milestone(item) === selected;
    visibleIssues = data.issues.filter(include);
    visiblePrs = data.prs.filter(include);
    closedIssues = visibleIssues.filter(issue => issue.closed_at != null);
    closedPrs = visiblePrs.filter(pr => pr.closed_at != null);
    openIssues = visibleIssues.filter(issue => issue.closed_at == null);
    openPrs = visiblePrs.filter(pr => pr.closed_at == null);
    renderMembers(); renderDurations(); renderIssues(); renderPrs(); renderCommits();
    renderOpenIssues(); renderOpenPrs();
  }
  const select = $('filter');
  [['all', 'すべて（指定Milestone＋未設定）'], ...data.milestones.map(value => [value, value]), ['未設定', '未設定']]
    .forEach(([value, label]) => { const option = el('option', label); option.value = value; select.append(option); });
  select.addEventListener('change', () => {
    $('copy-status').textContent = '';
    $('copy-fallback').hidden = true;
    render();
  });
  $('copy-button').addEventListener('click', copyOverview);
  $('meta').textContent = `${data.repository} · 生成: ${date(data.generatedAt)} · 対象: ${data.milestones.join('、')}`;

  const preview = $('preview');
  function addComments(item) {
    const comments = [...(item.comments || []), ...(item.reviewComments || [])];
    if (!comments.length) return;
    preview.append(el('strong', `コメント（${comments.length}件）`));
    comments.forEach(comment => {
      preview.append(el('div', `${comment.user || '不明'} · ${date(comment.created_at)}`, 'muted'));
      preview.append(el('div', comment.body || '', 'body'));
    });
  }
  function showPreview(anchor) {
    if (anchor.dataset.kind === 'commit') {
      const commit = commitMap.get(anchor.dataset.sha);
      if (!commit) return;
      preview.replaceChildren(el('strong', `コミット ${commit.sha.slice(0, 12)}`),
        el('div', `${commit.author} · ${date(commit.date)}`, 'muted'),
        el('div', commit.message, 'body'));
    } else {
    const item = (anchor.dataset.kind === 'issue' ? issueMap : prMap).get(Number(anchor.dataset.number));
    if (!item) return;
    preview.replaceChildren(el('strong', `${anchor.dataset.kind === 'issue' ? 'Issue' : 'PR'} #${item.number} ${item.title}`),
      el('div', `Milestone: ${milestone(item)} / 担当: ${assignees(item).join('、') || (anchor.dataset.kind === 'pr' ? owner(item) : '未設定')}`, 'muted'),
      el('div', item.body || '本文なし', 'body'));
    if (anchor.dataset.kind === 'pr') {
      preview.append(el('div', `レビュー: ${(item.reviews || []).map(r => `${r.user} ${r.state}`).join('、') || 'なし'} / マージ者: ${item.mergedBy || '—'}`));
    }
    addComments(item);
    }
    const rect = anchor.getBoundingClientRect();
    preview.style.left = `${Math.max(8, Math.min(rect.right + 10, window.innerWidth - Math.min(510, window.innerWidth - 16)))}px`;
    preview.style.top = `${Math.max(8, Math.min(rect.top, window.innerHeight - Math.min(420, window.innerHeight - 16)))}px`;
    preview.hidden = false;
  }
  document.addEventListener('mouseover', event => {
    const a = event.target.closest?.('a[data-kind]');
    if (a) showPreview(a);
  });
  document.addEventListener('mouseout', event => {
    if (event.target.closest?.('a[data-kind]') && !preview.contains(event.relatedTarget)) preview.hidden = true;
  });
  document.addEventListener('focusin', event => {
    const a = event.target.closest?.('a[data-kind]');
    if (a) showPreview(a);
  });
  document.addEventListener('focusout', event => {
    if (event.target.closest?.('a[data-kind]')) preview.hidden = true;
  });
  preview.addEventListener('mouseleave', () => { preview.hidden = true; });
  document.addEventListener('keydown', event => { if (event.key === 'Escape') preview.hidden = true; });
  render();
})();
