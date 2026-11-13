(() => {
  'use strict';
  const data = JSON.parse(document.getElementById('audit-data').textContent);
  const $ = id => document.getElementById(id);
  const issueMap = new Map(data.issues.map(item => [item.number, item]));
  const prMap = new Map(data.prs.map(item => [item.number, item]));
  const commitMap = new Map(data.mainCommits.map(item => [item.sha, item]));
  const allIssueNumbers = new Set(data.allIssueNumbers);
  const generatedTime = Date.parse(data.generatedAt);
  let visibleIssues = [], visiblePrs = [];

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
  function renderMembers() {
    const rows = data.members.map(member => {
      const assignedIssues = visibleIssues.filter(issue => assignees(issue).includes(member));
      const ownedPrs = visiblePrs.filter(pr => owner(pr) === member);
      const linkedPrs = ownedPrs.filter(pr => relatedNumbers(pr).length > 0);
      const reviewedPrs = visiblePrs.filter(pr => owner(pr) !== member && pr.reviews.some(review => review.user === member && review.submitted_at));
      const mergedPrs = visiblePrs.filter(pr => owner(pr) !== member && pr.mergedBy === member);
      return [member, assignedIssues.length, ownedPrs.length, linkedPrs.length, reviewedPrs.length, mergedPrs.length];
    });
    $('members').replaceChildren(table(['メンバー', '担当Issue', '担当PR', '関連Issueのある担当PR', '他者PRのレビュー', '他者PRのマージ'], rows));
  }
  function renderDurations() {
    const items = [
      ...visibleIssues.map(item => ({kind: 'issue', item, start: item.created_at, end: item.closed_at || data.generatedAt, endLabel: item.closed_at ? 'Close' : '生成時'})),
      ...visiblePrs.map(item => ({kind: 'pr', item, start: item.created_at, end: item.merged_at || item.closed_at || data.generatedAt, endLabel: item.merged_at ? 'マージ' : item.closed_at ? 'Close' : '生成時'}))
    ];
    items.sort((a, b) => (Date.parse(b.end) - Date.parse(b.start)) - (Date.parse(a.end) - Date.parse(a.start)));
    $('durations').replaceChildren(table(['種類', '項目', '開始（作成）', '終了', '経過時間'], items.map(({kind, item, start, end, endLabel}) => [
      kind === 'issue' ? 'Issue' : 'PR', link(kind, item, `#${item.number} ${item.title}`), date(start), `${date(end)}（${endLabel}）`, elapsed(start, end)
    ])));
  }
  function renderIssues() {
    const rows = visibleIssues.map(issue => {
      const prs = visiblePrs.filter(pr => relatedNumbers(pr).includes(issue.number)).map(pr => pr.number);
      const ac = /(^|\n)#{2,3}\s*AC(?:（受け入れ基準）)?/i.test(issue.body || '') ? '本文にAC見出しあり' : '本文で確認';
      const body = append(el('div'), detail(issue.body), el('div', `作成: ${date(issue.created_at)} / Close: ${date(issue.closed_at)}`, 'muted'));
      return [link('issue', issue, `#${issue.number} ${issue.title}`), milestone(issue), assignees(issue).join('、') || '未設定', issue.state, ac, joinedLinks('pr', prs), issue.closed_at ? (issue.closedByPr ? numberLink('pr', issue.closedByPr) : 'PRによるClose記録なし') : '—', body];
    });
    $('issues').replaceChildren(table(['Issue', 'Milestone', '担当者', '状態', 'AC', '関連PR', 'Close元', '詳細'], rows));
  }
  function renderPrs() {
    const rows = visiblePrs.map(pr => {
      const reviews = el('div');
      (pr.reviews || []).forEach((review, index) => {
        if (index) reviews.append(el('br'));
        reviews.append(`${review.user || '不明'}: ${review.state} (${date(review.submitted_at)})`);
      });
      if (!pr.reviews?.length) reviews.textContent = '—';
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
      return [link('pr', pr, `#${pr.number} ${pr.title}`), milestone(pr), owner(pr), pr.user?.login || '不明', joinedLinks('issue', relatedNumbers(pr)), reviews, pr.mergedBy || '—', details];
    });
    $('prs').replaceChildren(table(['PR', 'Milestone', '担当者', '作成者', '関連Issue', 'レビュー履歴', 'マージ者', '本文・ブランチ'], rows));
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
    renderMembers(); renderDurations(); renderIssues(); renderPrs(); renderCommits();
  }
  const select = $('filter');
  [['all', 'すべて（指定Milestone＋未設定）'], ...data.milestones.map(value => [value, value]), ['未設定', '未設定']]
    .forEach(([value, label]) => { const option = el('option', label); option.value = value; select.append(option); });
  select.addEventListener('change', render);
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
