class Public::PostsController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create, :show, :edit, :update, :destory, :search_tag]
  before_action :check_guest_user, only: [:new, :edit]
  before_action :ensure_correct_user, only: [:edit]

  def new
    @post = Post.new
    @post.photos.build
  end

  def create
    @post = Post.new(post_params)
    @tag_list = params[:post][:name].split(',')

    if @post.save
      if params[:post][:status] == "draft"
        redirect_to user_path(current_user), notice: '投稿を下書き保存しました'
      else
        @post.save_tag(@tag_list)
        redirect_to post_path(@post.id), notice: '投稿が完了しました'
      end
    else
      @post.photos.new
      render "new"
    end
  end

  def index
    @tag_list = Tag.limit(5).popular

    if params[:latest]
      @posts = Post.published.includes(:photos).page(params[:page]).per(8).latest
    elsif params[:old]
      @posts = Post.published.includes(:photos).page(params[:page]).per(8).old
    elsif params[:popular]
      @posts = Post.published.includes(:photos).page(params[:page]).per(8).popular
    else
      @posts = Post.published.includes(:photos).page(params[:page]).per(8).order(created_at: :DESC)
    end
  end

  def show
    @post = Post.find(params[:id])
    @user = @post.user
    if @post.status == 'draft' || @post.status == 'unpublished'
      unless @user == current_user
        redirect_to posts_path, alert: "この投稿は現在公開されておりません"
      end
    end
    @post_comment = PostComment.new
    @post_tag = @post.tags
  end

  def edit
    @post = Post.includes(:photos).find(params[:id])
    @post.photos.each do |photo|
      photo.image.cache!
    end
    @tag_list = @post.tags.pluck(:name).join(',')
  end

  def update
    @post = Post.includes(:photos).find(params[:id])
    @tag_list = params[:post][:name].split(',')
    if @post.update(post_params)
      if params[:post][:status] == "published"
        @post.update_tag(@tag_list)
        redirect_to post_path(@post.id), notice: '投稿が更新されました'
      elsif params[:post][:status]  == "draft"
        redirect_to user_path(current_user), notice: '下書きに登録しました。'
      else
        redirect_to user_path(current_user), notice: '非公開に設定しました'
      end
    else
      render "edit"
    end
  end

  def destroy
    post = Post.find(params[:id])
    post.destroy
    redirect_to posts_path, notice: '投稿を削除しました'
  end

  def search_tag
    @tag_list = Tag.limit(5).popular
    @tag = Tag.find(params[:tag_id])
    if params[:latest]
      @posts = @tag.posts.page(params[:page]).per(8).latest
    elsif params[:old]
      @posts = @tag.posts.page(params[:page]).per(8).old
    elsif params[:popular]
      @posts = @tag.posts.page(params[:page]).per(8).popular
    else
      @posts = @tag.posts.page(params[:page]).per(8).order(created_at: :DESC)
    end
  end

  private

  def ensure_correct_user
    @post = Post.find(params[:id])
    unless @post.user == current_user
      redirect_to posts_path, alert: "ユーザー情報が一致しませんでした"
    end
  end

  def check_guest_user
    if current_user.guest?
      redirect_to root_path, alert: "投稿する場合は会員登録を行ってください"
    end
  end

  def post_params
    params.require(:post).permit(:title, :shop_name, :address, :body, :status, photos_attributes: [:id, :_destroy, :image, :image_cache]).merge(user_id: current_user.id)
  end
end
