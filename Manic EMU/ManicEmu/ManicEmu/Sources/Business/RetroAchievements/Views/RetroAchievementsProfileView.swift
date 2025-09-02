//
//  RetroAchievementsProfileView.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class RetroAchievementsProfileView: BaseView {
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .never
        view.register(cellWithClass: RetroAchievementsProfileCell.self)
        view.showsVerticalScrollIndicator = false
        view.dataSource = self
        view.contentInset = UIEdgeInsets(top: 90, left: 0, bottom: Constants.Size.ContentInsetBottom, right: 0)
        return view
    }()
    
    private let username: String
    
    private var retroProfile = AchievementsProfile()
    
    var logoutSuccess: (()->Void)? = nil
    
    init(username: String) {
        self.username = username
        super.init(frame: .zero)
        backgroundColor = .clear
        
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        updateDatas()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, env in
            //item布局
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                 heightDimension: .fractionalHeight(1)))
            //group布局
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(595)), subitems: [item])
            group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            //section布局
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            
            return section
        }
        return layout
    }
    
    private func updateDatas() {
        if let url = URL(string: "https://retroachievements.org/API/API_GetUserSummary.php?u=\(username)&y=\(Constants.Cipher.RetroAPI)&g=5&a=1") {
            UIView.makeLoading()
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    UIView.hideLoading()
                    if let data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       json["errors"] == nil {
                        self.retroProfile = self.decode(json: json)
                        self.collectionView.reloadData()
                    } else {
                        UIView.makeToast(message: R.string.localizable.achievementsDataLoadFail())
                    }
                }
            }.resume()
        }
    }
    
    private func decode(json: [String: Any]) -> AchievementsProfile {
        var userPic = ""
        if let pic = json["UserPic"] as? String {
            userPic = "https://media.retroachievements.org\(pic)"
        }
        var lastActivityTimestamp = ""
        if let recentlyPlayeds = json["RecentlyPlayed"] as? [[String: Any]],
           let first = recentlyPlayeds.first,
           let lastPlayedTime = first["LastPlayed"] as? String,
           let lastPlayedTimeFormated = lastPlayedTime.date(withFormat: "yyyy-MM-dd HH:mm:ss")?.timeAgo() {
            lastActivityTimestamp = lastPlayedTimeFormated
        }
        var memberSince = ""
        if let memberSinceString = json["MemberSince"] as? String,
           let dateString = memberSinceString.dateTime?.dateString() {
            memberSince = dateString
        }
        var achievementCount = 0
        if let awarded = json["Awarded"] as? [String: [String: Any]] {
            for value in awarded.values {
                if let numAchieved = value["NumAchieved"] as? Int {
                    achievementCount += numAchieved
                }
            }
        }
        let totalSoftcorePoints = (json["TotalSoftcorePoints"] as? Int) ?? 0
        let totalHardcorePoints = (json["TotalPoints"] as? Int) ?? 0
        let rank = (json["Rank"] as? Int) ?? 0
        
        return AchievementsProfile(userPic: userPic, user: username, lastActivityTimestamp: lastActivityTimestamp, memberSince: memberSince, achievementCount: achievementCount, totalSoftcorePoints: totalSoftcorePoints, totalHardcorePoints: totalHardcorePoints, totalRanked: rank)
    }
}

extension RetroAchievementsProfileView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 1 }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withClass: RetroAchievementsProfileCell.self, for: indexPath)
        cell.setDatas(profile: retroProfile)
        cell.logoutSuccess = logoutSuccess
        return cell
    }
}
