const q = selector => document.querySelector(selector);
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const safeUrl = value => /^https:\/\/github\.com\//.test(value || '') ? esc(value) : '#';
const previewAttributes = url => {
  const match = /^https:\/\/github\.com\/([^/]+)\/([^/]+)\/(issues|pull)\/([1-9][0-9]*)(?:[?#].*)?$/.exec(url || '');
  if (!match || `${match[1]}/${match[2]}` !== report.repository) return '';
  return ` data-preview-kind="${match[3] === 'issues' ? 'issue' : 'pr'}" data-preview-number="${match[4]}"`;
};
const link = (url, label) => `<a href="${safeUrl(url)}"${previewAttributes(url)} target="_blank" rel="noopener noreferrer">${esc(label)}</a>`;
const duration = seconds => {
  if (seconds == null || !Number.isFinite(Number(seconds))) return '算定不可';
  const total = Math.max(0, Math.round(Number(seconds)));
  const days = Math.floor(total / 86400), hours = Math.floor(total % 86400 / 3600), minutes = Math.floor(total % 3600 / 60);
  return `${days ? days + '日' : ''}${hours ? hours + '時間' : ''}${minutes}分`;
};
const prDurationPeriod = pr => {
  const start = ({reflog: 'ブランチ作成', 'first-commit': '最初のコミット',
    'issue-created': 'Issue作成', 'pr-created': 'PR作成'})[pr.startSource] || '記録された開始時点';
  const end = pr.endSource === 'pr-merged' ? 'マージ' : 'Close';
  return `${start}から${end}まで`;
};
const prDurationText = pr => `${duration(pr.durationSeconds)}（${prDurationPeriod(pr)}）`;
const age = createdAt => duration((Date.parse(report.generatedAt) - Date.parse(createdAt)) / 1000);
const aiOptions = [
  ['none', '全く利用していない'],
  ['brainstorm', '要求分析に利用（brainstorm）'],
  ['plan-issues', 'Issue作成・登録に利用（plan-issues）'],
  ['implement-issue', '実装に利用（implement-issue）'],
  ['prepare-pr', 'PR作成に利用（prepare-pr）'],
  ['debug', 'デバッグに利用（debug）'],
  ['review-pr', 'レビューに利用（review-pr）'],
  ['other', 'その他']
];
const dodQuestions = [
  'すべてのIssueとPRにmilestoneが正しく設定されていますか？現時点で未完了のIssueおよびPRがある場合は今すぐに次のmilestoneを設定しましょう．',
  '自分の担当したすべてのIssueについて、assigneeとACが正しく記録されていますか？',
  'mainブランチに直接コミットしていませんか？',
  'すべてのCloseされた担当PRについて、「変更内容」と「AC確認結果」が適切に記載されていますか？',
  'すべてのCloseされた担当PRについて，「関連Issue」が正しく記載されている',
  'すべてのCloseされた担当PRについて、実装者以外がAC/差分を確認してレビューを行い、マージしていますか？'
];
const dodOptions = [
  [['correct', '正しく設定されている'], ['incorrect', '正しく設定されていないものがある'], ['no_assigned', '自分の担当したPR/Issueが存在しない']],
  [['correct', '担当したすべてのIssueについて正しく設定されている'], ['incorrect', 'ACあるいは担当者が設定されていない担当Issueがある'], ['no_assigned', '自分の担当したIssueが存在しない']],
  [['no_direct_main', '一切mainブランチに直接コミットしていない'], ['direct_main', 'mainブランチに直接コミットしたものがある']],
  [['complete', '「変更内容」と「AC確認結果」がすべてのClosedな担当PRに適切に記載されている'], ['missing', '記載が漏れている担当PRがある'], ['no_assigned', '担当PRが存在しない']],
  [['complete', 'すべてのClosedな担当PRについて「関連Issue」が正しく記載されている'], ['missing', '記載が漏れているPRがある'], ['no_assigned', '担当PRが存在しない']],
  [['reviewed', 'すべてのClosedな担当PRについて実装者以外がレビュアーとしてAC/差分を確認して結果を記述している'], ['same_reviewer', 'PRの担当者とレビュアーが共通のPRがある'], ['no_review_result', 'PRの担当者とレビュアーは異なるがレビュー結果が記載されていない'], ['no_merged', '担当PRが存在しないか，担当PRがマージされていない']]
];
const dodLabel = id => {
  const options = dodOptions[Number(id) - 1];
  const choice = report.dodAssessment?.[id]?.choice;
  return options.find(([value]) => value === choice)?.[1] || '未選択';
};
const aiLabel = number => {
  const answer = report.aiUsage?.[String(number)];
  if (!answer?.choices?.length) return '未選択';
  return answer.choices.map(key => key === 'other' ? `その他${answer.other ? '（' + answer.other + '）' : ''}` : aiOptions.find(([option]) => option === key)?.[1] || key).join('、');
};
const entryList = (items, formatter) => items.length ? items.map(formatter).join('') : '<p>該当なし</p>';
const section = (id, title, items, formatter) => `<section class="box detail-card" id="${id}"><h3 class="title is-5">${esc(title)}（${items.length}）</h3>${entryList(items, formatter)}</section>`;

const assigneeNames = item => (item.assignees || []).map(user => typeof user === 'string' ? user : user.login).filter(Boolean);
const ownerNames = pr => assigneeNames(pr).length ? assigneeNames(pr).join('、') : (typeof pr.author === 'string' ? pr.author : pr.author?.login) || '未設定';
const creatorName = item => typeof item.author === 'string' ? item.author : (item.author?.login || item.user?.login || '');
const spreadsheetCell = value => {
  const cleaned = String(value ?? '').replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, ' ').trim();
  return /^[=+\-@]/.test(cleaned) ? `'${cleaned}` : cleaned;
};
const spreadsheetDate = value => {
  if (!value) return '';
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return '';
  const date = new Date(timestamp + 9 * 60 * 60 * 1000);
  const two = number => String(number).padStart(2, '0');
  return `${date.getUTCFullYear()}/${two(date.getUTCMonth() + 1)}/${two(date.getUTCDate())} ${two(date.getUTCHours())}:${two(date.getUTCMinutes())}`;
};
const spreadsheetAi = number => {
  const answer = report.aiUsage?.[String(number)];
  if (!answer?.choices?.length) return '未選択';
  return answer.choices.map(choice => choice === 'none' ? '全く利用していない' :
    choice === 'other' ? `other${answer.other ? ': ' + answer.other : ''}` : choice).join('; ');
};
function reportItems() {
  const prs = new Map(), issues = new Map();
  const include = (map, item, category) => {
    if (!item?.number) return;
    const current = map.get(item.number);
    if (current) {
      if (!current.categories.includes(category)) current.categories.push(category);
      for (const [key, value] of Object.entries(item)) {
        if ((current[key] == null || current[key] === '') && value != null && value !== '') current[key] = value;
      }
      for (const related of item.relatedIssues || []) {
        if (!current.relatedIssues.some(issue => issue.number === related.number)) current.relatedIssues.push(related);
      }
    } else map.set(item.number, {...item, categories: [category], relatedIssues: [...(item.relatedIssues || [])]});
  };
  for (const pr of report.closedPullRequests) include(prs, pr, 'Close済み担当PR');
  for (const pr of report.mergedByStudent) include(prs, pr, '自分がマージしたPR');
  for (const pr of report.openPullRequests) include(prs, pr, '全体のOpen PR');
  const relatedPrs = new Map();
  for (const pr of prs.values()) {
    for (const issue of pr.relatedIssues) {
      include(issues, issue, 'PR関連Issue');
      if (!relatedPrs.has(issue.number)) relatedPrs.set(issue.number, new Set());
      relatedPrs.get(issue.number).add(pr.number);
    }
  }
  for (const issue of report.manuallyClosedIssues) include(issues, issue, '手動Close Issue');
  for (const issue of report.openIssues) include(issues, issue, '全体のOpen Issue');
  return {prs, issues, relatedPrs};
}
function spreadsheetTsv() {
  const headers = ['行種別', 'Milestone', '指標・区分', '件数/番号', 'タイトル・設問', 'GitHub URL',
    '主担当', '作成者', '所要時間', '作成日時', 'Close日時', 'マージ日時', 'マージ者', '関連Issue・PR', 'AI利用結果/DoD回答'];
  const rows = [headers];
  const add = values => rows.push(headers.map((_, index) => spreadsheetCell(values[index])));
  const s = report.summary;
  for (const [label, count] of [
    ['01 Close済み担当PR', s.closedPrCount], ['02 うちマージ済み', s.mergedPrCount],
    ['03 自分がマージしたPR', s.mergedByStudentCount], ['04 手動Close Issue', s.manuallyClosedIssueCount],
    ['05 総コミット', s.commitCount], ['06 総コメント', s.githubCommentCount],
    ['07 trouble report', s.troubleshootingCount], ['08 全体のOpen PR', s.openPrCount],
    ['09 全体のOpen Issue', s.openIssueCount]
  ]) add(['集計', report.milestone, label, count]);
  const {prs, issues, relatedPrs} = reportItems();
  for (const pr of prs.values()) {
    add(['PR', report.milestone, pr.categories.join('・'), pr.number, pr.title, pr.url,
      ownerNames(pr), creatorName(pr), pr.categories.includes('Close済み担当PR') && pr.durationSeconds != null ? duration(pr.durationSeconds) : '',
      spreadsheetDate(pr.createdAt), spreadsheetDate(pr.closedAt),
      spreadsheetDate(pr.mergedAt), typeof pr.mergedBy === 'string' ? pr.mergedBy : pr.mergedBy?.login,
      pr.relatedIssues.length ? pr.relatedIssues.map(issue => `Issue #${issue.number}`).join('、') : '関連Issueなし',
      pr.categories.includes('Close済み担当PR') ? spreadsheetAi(pr.number) : '']);
  }
  for (const issue of issues.values()) {
    const related = [...(relatedPrs.get(issue.number) || [])].map(number => `PR #${number}`).join('、');
    add(['Issue', report.milestone, issue.categories.join('・'), issue.number, issue.title, issue.url,
      assigneeNames(issue).join('、') || '未設定', creatorName(issue), '', spreadsheetDate(issue.createdAt),
      spreadsheetDate(issue.closedAt), '', '', related, '']);
  }
  dodQuestions.forEach((question, index) => {
    const row = Array(headers.length).fill('');
    row[0] = 'DoD'; row[1] = report.milestone; row[2] = '自己評価'; row[3] = index + 1;
    row[4] = question; row[14] = dodLabel(String(index + 1));
    add(row);
  });
  return rows.map(row => row.join('\t')).join('\n');
}
const plainLink = (label, url) => `${label} (${url})`;
function overviewRows() {
  const s = report.summary, rows = [];
  const add = (plain, html = esc(plain), depth = 0) => rows.push({plain: `${'  '.repeat(depth)}${plain}`, html, depth});
  add(`週次開発レビュー @${report.student}`);
  add(`Milestone: ${report.milestone}`);
  add(`Close済み担当PR: ${s.closedPrCount}件（うちマージ済み ${s.mergedPrCount}件）`);
  for (const pr of report.closedPullRequests) {
    const status = pr.mergedAt ? '[Merged]' : '[NotMerged]';
    const timing = prDurationText(pr);
    const label = `${status}PR #${pr.number} ${pr.title}`;
    add(`${plainLink(label, pr.url)}: ${timing}`, `${link(pr.url, label)}: ${esc(timing)}`, 1);
    for (const issue of pr.relatedIssues || []) {
      const issueLabel = `[${String(issue.state).toLowerCase() === 'closed' ? 'Closed' : 'Open'}]Issue #${issue.number} ${issue.title}`;
      add(`- ${plainLink(issueLabel, issue.url)}`, `- ${link(issue.url, issueLabel)}`, 2);
    }
    if (!pr.relatedIssues?.length) add('- 関連Issueなし', '- 関連Issueなし', 2);
  }
  add(`自分がマージしたPR: ${s.mergedByStudentCount}件`);
  for (const pr of report.mergedByStudent) {
    const label = `PR #${pr.number} [${ownerNames(pr)}] ${pr.title}`;
    add(plainLink(label, pr.url), link(pr.url, label), 1);
  }
  add(`手動でCloseされたIssue: ${s.manuallyClosedIssueCount}件`);
  for (const issue of report.manuallyClosedIssues) {
    const label = `Issue #${issue.number} ${issue.title}`;
    add(plainLink(label, issue.url), link(issue.url, label), 1);
  }
  add(`総コミット: ${s.commitCount}件`);
  add(`総コメント: ${s.githubCommentCount}件`);
  add(`trouble report: ${s.troubleshootingCount}件`);
  for (const [title, items, kind] of [
    ['Open PR', report.openPullRequests, 'PR'], ['Open Issue', report.openIssues, 'Issue']
  ]) {
    add(`${title}: ${items.length}件`);
    for (const item of items) {
      const suffix = ` [assignee: ${assigneeNames(item).join('、') || '未設定'}] [milestone: ${item.milestone || '未設定'}]`;
      const label = `${kind} #${item.number} ${item.title}`;
      add(`${plainLink(label, item.url)}${suffix}`, `${link(item.url, label)}${esc(suffix)}`, 1);
    }
  }
  add('PRごとのAI利用:');
  for (const pr of report.closedPullRequests) add(`PR #${pr.number}: ${aiLabel(pr.number)}`, `PR #${pr.number}: ${esc(aiLabel(pr.number))}`, 1);
  add('DoD自己評価:');
  dodQuestions.forEach((_, index) => add(`${index + 1}. ${dodLabel(String(index + 1))}`, undefined, 1));
  return rows;
}
const overviewHtml = () => `<div class="overview-content">${overviewRows().map(row => `<p class="overview-row overview-depth-${row.depth}" style="margin:2px 0;padding-left:${row.depth * 24}px">${row.html}</p>`).join('')}</div>`;

function renderOverview() {
  const s = report.summary;
  q('#report-meta').textContent = `@${report.student} · ${report.milestone}`;
  q('#overview-metrics').innerHTML = [
    ['closed-prs', 'Close済み担当PR', s.closedPrCount],
    ['merged-by-student', '自分がマージしたPR', s.mergedByStudentCount],
    ['manual-issues', '手動Close Issue', s.manuallyClosedIssueCount],
    ['commits', 'コミット', s.commitCount],
    ['comments', 'コメント', s.githubCommentCount],
    ['trouble', 'trouble report', s.troubleshootingCount],
    ['open-prs', 'Open PR', s.openPrCount],
    ['open-issues', 'Open Issue', s.openIssueCount]
  ].map(([id, label, count]) => `<a class="metric-card" href="#${id}"><span>${esc(label)}</span><strong>${count}</strong></a>`).join('');
  q('#overview-text').innerHTML = overviewHtml();
  const unansweredAi = report.closedPullRequests.filter(pr => !report.aiUsage?.[String(pr.number)]?.choices?.length);
  q('#ai-warning').innerHTML = unansweredAi.length ? `<div class="notification warning">AI利用が未選択のClose済み担当PRが${unansweredAi.length}件あります: ${unansweredAi.map(pr => `<a href="#pr-${pr.number}">PR #${pr.number}</a>`).join('、')}</div>` : '';
  const unansweredDod = dodQuestions.map((_, index) => index + 1).filter(number => dodLabel(String(number)) === '未選択');
  q('#dod-warning').innerHTML = unansweredDod.length ? `<div class="notification warning">DoD自己評価が未選択の項目が${unansweredDod.length}件あります: ${unansweredDod.map(number => `<a href="#dod-item-${number}">${number}番</a>`).join('、')}</div>` : '';
}

function renderDodForm() {
  q('#dod-form-items').innerHTML = dodQuestions.map((question, index) => {
    const id = String(index + 1);
    const targets = index === 0 ? [...report.dodIssues, ...report.dodPullRequests] : index === 1 ? report.dodIssues : index === 2 ? [] : report.closedPullRequests;
    const kind = index === 0 ? 'Issue・PR' : index === 1 ? 'Issue' : index === 2 ? 'コミット' : 'PR';
    const links = targets.map(item => link(item.url, `${item.url?.includes('/pull/') ? 'PR' : 'Issue'}#${item.number}`)).join('、') || '対象なし';
    const note = index === 2
      ? `<p class="meta">自身のmainブランチにおける全コミットは${link(`https://github.com/${report.repository}/commits/main/?author=${encodeURIComponent(report.student)}`, 'Git履歴')}で確認してください。この画面のコミット一覧にはMilestoneのPR外やmainへの直接コミットは表示されません。</p>`
      : '';
    const targetInfo = index === 2 ? '' : `<p class="meta">対象${kind}: ${targets.length}件 — ${links}</p>`;
    const controls = `<div class="select is-fullwidth"><select id="dod-${id}" data-dod="${id}"><option value="">未選択</option>${dodOptions[index].map(([value, label]) => `<option value="${value}" ${report.dodAssessment?.[id]?.choice === value ? 'selected' : ''}>${esc(label)}</option>`).join('')}</select></div>`;
    return `<div class="dod-item" id="dod-item-${id}"><p class="label">${id}. ${esc(question)}</p>${targetInfo}${note}${controls}<p class="save-status" id="dod-status-${id}" aria-live="polite"></p></div>`;
  }).join('');
}

function aiControls(pr) {
  const answer = report.aiUsage?.[String(pr.number)] || {choices: [], other: ''};
  return `<fieldset class="ai-controls" data-pr="${pr.number}"><legend class="label">AI利用（複数選択可）</legend><div class="ai-grid">${aiOptions.map(([value, label]) => `<label class="checkbox"><input type="checkbox" value="${value}" ${answer.choices?.includes(value) ? 'checked' : ''}> ${esc(label)}</label>`).join('')}</div><label class="label other-label" for="other-${pr.number}">その他の内容</label><input class="input" id="other-${pr.number}" data-other type="text" maxlength="500" value="${esc(answer.other || '')}" ${answer.choices?.includes('other') ? '' : 'disabled'}><p class="save-status" aria-live="polite"></p></fieldset>`;
}

const detailFields = fields => `<dl class="detail-fields">${fields.map(([label, value, html]) =>
  `<div><dt>${esc(label)}</dt><dd>${html ? (value || 'なし') : esc(value || 'なし')}</dd></div>`).join('')}</dl>`;
const githubField = item => ['GitHub URL', link(item.url, item.url), true];
const issueFields = (issue, relatedPrs, prs) => {
  const links = [...(relatedPrs.get(issue.number) || [])].map(number => {
    const pr = prs.get(number);
    return pr ? link(pr.url, `PR #${number}`) : `PR #${number}`;
  }).join('、');
  return detailFields([
    ['区分', issue.categories?.join('・') || 'PR関連Issue'], ['集計Milestone', report.milestone], githubField(issue),
    ['主担当', assigneeNames(issue).join('、') || '未設定'], ['作成者', creatorName(issue)],
    ['作成日時（日本時間）', spreadsheetDate(issue.createdAt)], ['Close日時（日本時間）', spreadsheetDate(issue.closedAt)],
    ['関連PR', links, true]
  ]);
};
const relatedIssueCard = (issue, issues, relatedPrs, prs) => {
  const record = issues.get(issue.number) || issue;
  const state = String(issue.state).toLowerCase() === 'closed' || issue.closedAt ? 'Closed' : 'Open';
  return `<div class="related-record"><p>${link(issue.url, `[${state}] Issue #${issue.number} ${issue.title}`)}</p>${issueFields(record, relatedPrs, prs)}</div>`;
};
function prRecord(pr, items, {id, editable = false, collapsible = false} = {}) {
  const heading = link(pr.url, `PR #${pr.number} ${pr.title}`);
  const related = pr.relatedIssues.length ? pr.relatedIssues.map(issue =>
    relatedIssueCard(issue, items.issues, items.relatedPrs, items.prs)).join('') : '<p>関連Issueなし</p>';
  const fields = detailFields([
    ['区分', pr.categories.join('・')], ['集計Milestone', report.milestone], githubField(pr),
    ['主担当', ownerNames(pr)], ['作成者', creatorName(pr)],
    ['作成日時（日本時間）', spreadsheetDate(pr.createdAt)], ['Close日時（日本時間）', spreadsheetDate(pr.closedAt)],
    ['マージ日時（日本時間）', spreadsheetDate(pr.mergedAt)],
    ['マージ者', typeof pr.mergedBy === 'string' ? pr.mergedBy : pr.mergedBy?.login],
    ...(pr.milestone ? [['GitHubのMilestone', pr.milestone]] : [])
  ]);
  const ai = pr.categories.includes('Close済み担当PR')
    ? `<p>AI利用結果: <span data-ai-result="${pr.number}">${esc(spreadsheetAi(pr.number))}</span></p>` : '';
  const timing = pr.durationSeconds == null ? '' : `<p>所要時間: ${esc(prDurationText(pr))}</p>`;
  const startEnd = pr.startAt ? `<p class="meta">開始: ${esc(pr.startAt)}（${esc(pr.startSource)}）／終了: ${esc(pr.endAt)}（${esc(pr.endSource)}）</p>` : '';
  const body = `<div class="record-content">${fields}<div class="related-items"><h5>関連Issue</h5>${related}</div>${ai}${timing}${startEnd}${editable ? aiControls(pr) : ''}${collapsible ? `<p class="description">${esc(pr.body || '本文なし')}</p>` : ''}</div>`;
  return collapsible
    ? `<details class="list-item" id="${id}"><summary>${heading} · assignee: ${esc(ownerNames(pr))} · milestone: ${esc(pr.milestone || '未設定')} · 作成から${age(pr.createdAt)}</summary>${body}</details>`
    : `<article class="list-item" id="${id}"><h4 class="title is-6">${heading}</h4>${body}</article>`;
}
function issueRecord(issue, items, {id, collapsible = false} = {}) {
  const heading = link(issue.url, `Issue #${issue.number} ${issue.title}`);
  const fields = issueFields(issue, items.relatedPrs, items.prs);
  const milestone = issue.milestone ? `<p class="meta">GitHubのMilestone: ${esc(issue.milestone)}</p>` : '';
  const body = `<div class="record-content">${fields}${milestone}<p class="description">${esc(issue.body || '本文なし')}</p></div>`;
  return collapsible
    ? `<details class="list-item" id="${id}"><summary>${heading} · assignee: ${esc(assigneeNames(issue).join('、') || '未設定')} · milestone: ${esc(issue.milestone || '未設定')} · 作成から${age(issue.createdAt)}</summary>${body}</details>`
    : `<article class="list-item" id="${id}"><h4 class="title is-6">${heading}</h4>${body}</article>`;
}
function renderDetails() {
  const items = reportItems();
  q('#details').innerHTML = '<h2 class="title is-3 section-title">詳細表示</h2>' +
    section('closed-prs', 'Close済み担当PR', report.closedPullRequests, pr => prRecord(items.prs.get(pr.number), items, {id: `pr-${pr.number}`, editable: true})) +
    section('merged-by-student', '自分がマージしたPR', report.mergedByStudent, pr => prRecord(items.prs.get(pr.number), items, {id: `merged-pr-${pr.number}`})) +
    section('manual-issues', '手動でCloseされたIssue', report.manuallyClosedIssues, issue => issueRecord(items.issues.get(issue.number), items, {id: `manual-issue-${issue.number}`})) +
    section('commits', 'コミット', report.commits, commit => `<div class="list-item">${link(commit.html_url, `${commit.sha?.slice(0, 8)} ${commit.message?.split('\n')[0] || ''}`)}</div>`) +
    section('comments', 'GitHubコメント', report.githubComments, comment => `<div class="list-item">${link(comment.html_url, comment.body?.slice(0, 160) || 'コメント')} <span class="meta">${esc(comment.created_at)}</span></div>`) +
    section('trouble', 'trouble report', report.troubleshooting, item => `<div class="list-item">${link(item.url, item.subject)} <span class="meta">${esc(item.at)}</span></div>`);
  q('#unfinished').innerHTML = '<h2 class="title is-3 section-title">未完了</h2><p class="meta">全Milestoneに属する全員のOpen項目です。経過時間はレポート生成時点の値です。</p>' +
    section('open-prs', 'Open PR', report.openPullRequests, pr => prRecord(items.prs.get(pr.number), items, {id: `open-pr-${pr.number}`, collapsible: true})) +
    section('open-issues', 'Open Issue', report.openIssues, issue => issueRecord(items.issues.get(issue.number), items, {id: `open-issue-${issue.number}`, collapsible: true}));
}

async function postJson(path, payload) {
  // ローカルサーバはContent-Lengthを文字数として読むため、POST本文をASCIIのJSONにする。
  const body = JSON.stringify(payload).replace(/[^\x00-\x7f]/g, char => `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`);
  const response = await fetch(path, {method: 'POST', headers: {'Content-Type': 'application/json'}, body});
  if (!response.ok) throw new Error('保存できませんでした');
}

const preview = q('#github-preview');
let activePreviewLink = null, previewSequence = 0, previewHideTimer;
const cancelPreviewHide = () => { if (previewHideTimer) clearTimeout(previewHideTimer); previewHideTimer = undefined; };
function hidePreview() {
  cancelPreviewHide();
  activePreviewLink = null;
  previewSequence++;
  preview.hidden = true;
  preview.innerHTML = '';
}
const schedulePreviewHide = () => { cancelPreviewHide(); previewHideTimer = setTimeout(hidePreview, 180); };
function positionPreview(anchor) {
  const bounds = anchor.getBoundingClientRect();
  preview.style.left = `${Math.max(8, Math.min(bounds.right + 12, window.innerWidth - 540))}px`;
  preview.style.top = `${Math.max(8, Math.min(bounds.top, window.innerHeight - 420))}px`;
}
function previewHtml(item) {
  const meta = [`状態: ${item.state || '不明'}`, `作成者: ${item.author || '不明'}`,
    `担当者: ${(item.assignees || []).join('、') || '未設定'}`, `Milestone: ${item.milestone || '未設定'}`,
    `ラベル: ${(item.labels || []).join('、') || 'なし'}`];
  const comments = (item.comments || []).map(comment => `<article class="preview-entry"><strong>${esc(comment.author || '不明')}</strong><small>${esc(comment.createdAt || '')}</small><div class="preview-body">${esc(comment.body || '')}</div></article>`).join('');
  const reviews = (item.reviews || []).map(review => `<article class="preview-entry"><strong>${esc(review.author || '不明')} · ${esc(review.state || '')}</strong><small>${esc(review.submittedAt || '')}</small><div class="preview-body">${esc(review.body || '')}</div></article>`).join('');
  return `<h3>${esc(item.kind === 'pr' ? 'PR' : 'Issue')} #${esc(item.number)} ${esc(item.title || '')}</h3><p>${meta.map(esc).join(' · ')}</p><div class="preview-body">${esc(item.body || '本文なし')}</div>${comments ? `<h4>コメント</h4>${comments}` : ''}${reviews ? `<h4>レビュー</h4>${reviews}` : ''}<p><a href="${safeUrl(item.url)}" target="_blank" rel="noopener noreferrer">GitHubで開く</a></p>`;
}
async function showPreview(anchor) {
  cancelPreviewHide();
  if (activePreviewLink === anchor && !preview.hidden) return;
  activePreviewLink = anchor;
  const sequence = ++previewSequence;
  preview.innerHTML = '<p>GitHubの内容を取得しています…</p>';
  preview.hidden = false;
  positionPreview(anchor);
  try {
    const kind = anchor.dataset.previewKind, number = anchor.dataset.previewNumber;
    const response = await fetch(`/api/preview?kind=${kind}&number=${number}`, {cache: 'no-store'});
    if (!response.ok) throw new Error('取得失敗');
    const item = await response.json();
    if (sequence === previewSequence && activePreviewLink === anchor) preview.innerHTML = previewHtml(item);
  } catch (_) {
    if (sequence === previewSequence && activePreviewLink === anchor) preview.innerHTML = '<p>内容を取得できませんでした。リンクからGitHubを開いてください。</p>';
  }
}
document.addEventListener('pointerover', event => {
  const anchor = event.target.closest?.('a[data-preview-kind]');
  if (anchor) showPreview(anchor);
});
document.addEventListener('pointerout', event => {
  const anchor = event.target.closest?.('a[data-preview-kind]');
  if (anchor === activePreviewLink && !anchor.contains(event.relatedTarget)) schedulePreviewHide();
});
document.addEventListener('focusin', event => {
  const anchor = event.target.closest?.('a[data-preview-kind]');
  if (anchor) showPreview(anchor);
});
document.addEventListener('focusout', event => {
  const anchor = event.target.closest?.('a[data-preview-kind]');
  if (anchor === activePreviewLink) schedulePreviewHide();
});
document.addEventListener('keydown', event => { if (event.key === 'Escape') hidePreview(); });
preview.addEventListener('pointerenter', cancelPreviewHide);
preview.addEventListener('pointerleave', schedulePreviewHide);

q('#report-select').addEventListener('change', event => { location.search = '?report=' + encodeURIComponent(event.target.value); });
q('#copy-button').addEventListener('click', async () => {
  try {
    await navigator.clipboard.writeText(spreadsheetTsv());
    q('#copy-status').textContent = 'タブ区切りの概要をコピーしました。';
  } catch (_) {
    q('#copy-status').textContent = 'コピーできませんでした。ブラウザのクリップボード権限を確認してください。';
  }
});
q('#dod-form-items').addEventListener('change', async event => {
  const select = event.target.closest('select[data-dod]');
  if (!select) return;
  const id = select.dataset.dod, previous = report.dodAssessment?.[id]?.choice || '';
  const status = q(`#dod-status-${id}`);
  select.disabled = true;
  try {
    await postJson('/api/dod-assessment', {item: id, choice: select.value});
    report.dodAssessment[id] = select.value ? {choice: select.value} : undefined;
    status.textContent = '保存しました。';
    renderOverview();
  } catch (_) {
    select.value = previous;
    status.textContent = '保存できませんでした。再試行してください。';
  } finally { select.disabled = false; }
});
async function saveAiControls(fieldset) {
  const number = fieldset.dataset.pr;
  const choices = [...fieldset.querySelectorAll('input[type="checkbox"]:checked')].map(input => input.value);
  const other = choices.includes('other') ? fieldset.querySelector('[data-other]').value.trim() : '';
  const status = fieldset.querySelector('.save-status');
  try {
    await postJson('/api/ai-usage', {pr: number, choices, other});
    report.aiUsage[number] = {choices, other};
    status.textContent = '保存しました。';
    q('#details').querySelectorAll?.(`[data-ai-result="${number}"]`).forEach(label => { label.textContent = spreadsheetAi(number); });
    renderOverview();
  } catch (_) { status.textContent = '保存できませんでした。再試行してください。'; }
}
const aiSaveQueues = new Map();
q('#details').addEventListener('change', event => {
  const fieldset = event.target.closest('fieldset[data-pr]');
  if (!fieldset) return;
  if (event.target.type === 'checkbox') {
    const none = fieldset.querySelector('input[value="none"]');
    if (event.target.value === 'none' && none.checked) fieldset.querySelectorAll('input[type="checkbox"]').forEach(input => { if (input !== none) input.checked = false; });
    if (event.target.value !== 'none' && event.target.checked) none.checked = false;
    fieldset.querySelector('[data-other]').disabled = !fieldset.querySelector('input[value="other"]').checked;
  }
  const number = fieldset.dataset.pr;
  const pending = aiSaveQueues.get(number) || Promise.resolve();
  aiSaveQueues.set(number, pending.catch(() => {}).then(() => saveAiControls(fieldset)));
});
renderDodForm();
renderDetails();
renderOverview();
setInterval(() => fetch('/api/heartbeat', {cache: 'no-store'}).catch(() => {}), 5000);
fetch('/api/heartbeat').catch(() => {});
